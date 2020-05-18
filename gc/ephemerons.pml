#define NUM_DOMAINS 2
#define BUDGET 1
#define MAX_WORK 2
#define EPHE_DEPTH 3

#define PHASE_MARK 0
#define PHASE_SWEEP_EPHE 1

byte dlMarkWork[NUM_DOMAINS];
byte dlSweepWork[NUM_DOMAINS];
byte dlSweepEpheWork[NUM_DOMAINS];
byte dlEpheDepth[NUM_DOMAINS];
chan join = [NUM_DOMAINS] of { bool };

byte dlMarkingDone[NUM_DOMAINS];
byte dlEpheRound[NUM_DOMAINS];
byte dlSweepEpheDone[NUM_DOMAINS];

byte gNumDomsToMark;
byte gEpheRound;
byte gNumDomsMarkedEphe;
byte gNumDomsSweptEphe;
bool gPhase;

bool gFinishedCycle;

inline sweepSlice (budget, domainId) {
  printf ("[%d] sweepSlice: dlSweepWork[%d]=%d\n",
          domainId, domainId, dlSweepWork[domainId]);
  if
  :: (dlSweepWork[domainId] >= budget) ->
        dlSweepWork[domainId] = dlSweepWork[domainId] - budget;
        budget = 0;
  :: else ->
        budget = budget - dlSweepWork[domainId];
        dlSweepWork[domainId] = 0;
  fi;
}

inline markSlice (budget, domainId) {
  printf ("[%d] markSlice: dlMarkWork[%d]=%d\n",
          domainId, domainId, dlMarkWork[domainId]);
  if
  :: (dlMarkWork[domainId] >= budget) ->
        dlMarkWork[domainId] = dlMarkWork[domainId] - budget;
        budget = 0;
  :: else ->
        budget = budget - dlMarkWork[domainId];
        dlMarkWork[domainId] = 0;
  fi;
}

inline sweepEphe (budget, domainId) {
  printf ("[%d] sweepEphe\n", domainId);
  if
  :: (dlSweepEpheWork[domainId] >= budget) ->
        dlSweepEpheWork[domainId] = dlSweepEpheWork[domainId] - budget;
        budget = 0;
  :: else ->
        budget = budget - dlSweepEpheWork[domainId];
        dlSweepEpheWork[domainId] = 0;
  fi;
}

inline markEphe (budget, cached, domainId) {
  printf ("[%d] markEphe(1): budget=%d\n", domainId, budget);
  if
  :: /* Case: New ephemeron data marked */
     (budget > 0 && dlEpheDepth[domainId] > 0) -> {
        gNumDomsToMark++;
        dlMarkingDone[domainId] = 0;
        byte w;
        select (w : 0 .. MAX_WORK);
        dlMarkWork[domainId] = w;
        dlEpheDepth[domainId]--;
        /* Fully marked ephemrons for this round (budget > 0) */
      }
  :: skip
  fi;
  printf ("[%d] markEphe(2): budget=%d dlEpheDepth[%d]=%d\n",
          domainId, budget, domainId, dlEpheDepth[domainId]);
}

inline changePhase () {
  d_step {
    printf ("[%d] changePhase: gNumDomsToMark=%d, gNumDomsMarkedEphe=%d, gEpheRound=%d\n",
            domainId, gNumDomsToMark, gNumDomsMarkedEphe, gEpheRound);
    if
    :: (gPhase == PHASE_MARK && gNumDomsToMark == 0 &&
        gNumDomsMarkedEphe == NUM_DOMAINS) ->
          gPhase = PHASE_SWEEP_EPHE;
    :: else -> skip
    fi;
  }
  if
  :: (gPhase == PHASE_SWEEP_EPHE &&
      gNumDomsSweptEphe == NUM_DOMAINS) ->
        gFinishedCycle = 1;
  :: else -> skip
  fi
}

inline majorSlice (budget, domainId) {
  sweepSlice (budget /* out */, domainId);
  markSlice (budget /* out */, domainId);

  printf ("[%d] majorSlice: budget=%d, dlMarkingDone[%d]=%d\n",
          domainId, budget, domainId, dlMarkingDone[domainId]);
  if
  :: (budget > 0 && dlMarkingDone[domainId] == 0) ->
        dlMarkingDone[domainId] = 1;
        d_step {
          gNumDomsToMark--;
          gEpheRound++;
          gNumDomsMarkedEphe = 0;
        }
  :: else -> skip;
  fi;

  /* Ephemeron Mark */
  byte cached = gEpheRound;
  if
  :: (cached > dlEpheRound[domainId]) ->
        markEphe (budget /* out */, cached, domainId);
        if
        :: (budget && dlMarkingDone[domainId]) ->
              dlEpheRound[domainId] = cached;
              d_step {
                if
                :: (cached == gEpheRound) -> gNumDomsMarkedEphe++;
                :: else -> skip;
                fi
              }
        :: else -> skip
        fi
  :: else -> skip
  fi;

  /* Ephemeron Sweep */
  if
  :: (gPhase == PHASE_SWEEP_EPHE) ->
        sweepEphe (budget /* out */, domainId);
        if
        :: (budget && dlSweepEpheDone[domainId] == 0) ->
              dlSweepEpheDone[domainId] = 1;
              d_step { gNumDomsSweptEphe++; }
        :: else -> skip;
        fi
  :: else -> skip;
  fi;

  changePhase ();
}

proctype domain (byte domainId) {
  byte budget;

loop:
  budget = BUDGET;
  majorSlice (budget /* out */, domainId);
  if
  :: (gFinishedCycle == 0) -> goto loop;
  :: else -> skip
  fi;

  join!1;
}

init {
  byte w;
  byte i;

  for (i : 0 .. NUM_DOMAINS - 1) {
    select (w : 0 .. MAX_WORK);
    dlMarkWork[i] = w;
    select (w : 0 .. MAX_WORK);
    dlSweepWork[i] = w;
    select (w : 0 .. MAX_WORK);
    dlSweepEpheWork[i] = w;

    dlMarkingDone[i] = 0;
    dlEpheRound[i] = 0;
    dlSweepEpheDone[i] = 0;
    dlEpheDepth[i] = EPHE_DEPTH;
  }

  gNumDomsToMark = NUM_DOMAINS;
  gEpheRound = 0;
  gNumDomsMarkedEphe = 0;
  gNumDomsSweptEphe = 0;
  gPhase = PHASE_MARK;
  gFinishedCycle = 0;

  atomic {
    i = 0;
    do
    :: i < NUM_DOMAINS ->
         run domain(i);
         i++;
    :: i == NUM_DOMAINS ->
         break;
    od
  }

  bool b;
  for (i : 0 .. NUM_DOMAINS - 1) {
    join?b;
  }

  assert (gFinishedCycle == 1);
  for (i : 0 .. NUM_DOMAINS - 1) {
    assert (dlMarkingDone[i] == 1);
    assert (dlMarkWork[i] == 0);
    assert (dlSweepWork[i] == 0);
    assert (dlSweepEpheWork[i] == 0);
  }
  assert (gNumDomsToMark == 0);
  assert (gNumDomsMarkedEphe == NUM_DOMAINS);
  assert (gNumDomsSweptEphe == NUM_DOMAINS);
}
