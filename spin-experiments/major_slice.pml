#define N 1
#define BUDGET 4

byte dlMarkWork[N];
byte dlSweepWork[N];
chan join;

byte dlMarkingDone[N];

byte gNumDomsToMark;

inline sweepSlice(domainId, budget, retVal) {
  if
	:: (dlSweepWork[domainId] >= budget) ->
	      dlSweepWork[domainId] = dlSweepWork[domainId] - budget;
				budget = 0;
	:: else ->
	      budget = budget - dlSweepWork[domainId];
	      dlSweepWork[domainId] = 0;
	fi;

	retVal = budget;
}

inline markSlice (domainId, budget, retVal) {
  if
	:: (dlMarkWork[domainId] >= budget) ->
	      dlMarkWork[domainId] = dlMarkWork[domainId] - budget;
				budget = 0;
	:: else -> {
	      budget = budget - dlMarkWork[domainId];
	      dlMarkWork[domainId] = 0;
				}
	fi;

	retVal = budget;
}

inline majorSlice (domainId, budget, retVal) {
	sweepSlice (domainId, budget, retVal);
	budget = retVal;

	markSlice (domainId, budget, retVal);
	budget = retVal;

  if
	:: (budget > 0 && dlMarkingDone[domainId] == 0) ->
	      dlMarkingDone[domainId] = 1;
				d_step { gNumDomsToMark--; }
  :: else -> skip;
	fi

	retVal = budget;
}

proctype domain (byte domainId) {
  byte budget = BUDGET;
	byte retVal = 0;

loop:
  majorSlice (domainId, BUDGET, retVal);
  budget = retVal;
	if
	:: (budget == 0) -> goto loop;
	:: else -> skip
	fi;
	join!1;
}

init {
  byte w;
	byte i;

	for (i : 0 .. N - 1) {
	  select (w : 0 .. 255);
		dlMarkWork[i] = w;
	  select (w : 0 .. 255);
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
	for (i : 0 to N - 1) {
	  join?b;
	}

	for (i : 0 .. N - 1) {
	  assert (dlMarkingDone[i] == 1);
		assert (dlMarkWork[i] == 0);
		assert (dlSweepWork[i] == 0);
	}
  assert (gNumDomsToMark == 0);
}
