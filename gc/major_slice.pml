#define N 2
#define BUDGET 4
#define MAX_WORK 12

byte dlMarkWork[N];
byte dlSweepWork[N];
chan join = [N] of { bool };

byte dlMarkingDone[N];

byte gNumDomsToMark;

inline sweepSlice (budget, domainId) {
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
  if
	:: (dlMarkWork[domainId] >= budget) ->
	      dlMarkWork[domainId] = dlMarkWork[domainId] - budget;
				budget = 0;
	:: else ->
	      budget = budget - dlMarkWork[domainId];
	      dlMarkWork[domainId] = 0;
	fi;
}

inline majorSlice (budget, domainId) {
  sweepSlice (budget /* modified */, domainId);
  markSlice (budget /* modified */, domainId);

  if
	:: (budget > 0 && dlMarkingDone[domainId] == 0) ->
	      dlMarkingDone[domainId] = 1;
				d_step { gNumDomsToMark--; }
  :: else -> skip;
	fi;
}

proctype domain (byte domainId) {
  byte budget;

loop:
  printf("domain=%d markWork=%d sweepWork=%d\n",
	       domainId, dlMarkWork[domainId], dlSweepWork[domainId]);
  budget = BUDGET;
	majorSlice (budget /* modified */, domainId);
	if
	:: (budget == 0) -> goto loop;
	:: else -> skip
	fi;

  printf("domain=%d markWork=%d sweepWork=%d\n",
	       domainId, dlMarkWork[domainId], dlSweepWork[domainId]);

	join!1;
}

init {
  byte w;
	byte i;

	for (i : 0 .. N - 1) {
	  select (w : 0 .. MAX_WORK);
		dlMarkWork[i] = w;
	  select (w : 0 .. MAX_WORK);
		dlSweepWork[i] = w;
	  dlMarkingDone[i] = 0;
	}

  gNumDomsToMark = N;

  atomic {
	  i = 0;
		do
		:: i < N ->
		     run domain(i);
				 i++;
	  :: i == N ->
		     break;
		od
	}

  bool b;
	for (i : 0 .. N - 1) {
	  join?b;
	}

	for (i : 0 .. N - 1) {
	  assert (dlMarkingDone[i] == 1);
		assert (dlMarkWork[i] == 0);
		assert (dlSweepWork[i] == 0);
	}
  assert (gNumDomsToMark == 0);
}
