/* Run as
     $ PROP=p% make ltl
   where % = 0 to 5.
*/
#define N 3
#define EPHEMERON_DEPTH 2

byte num_domains_to_mark;
byte num_domains_to_sweep;
byte num_domains_to_ephe_sweep;
int ephe_cycle;
int ephe_cycle_in_domain[N];
bool ephe_sweep;

ltl p0 { <> ([] (num_domains_to_sweep == 0)) }
ltl p1 { <> ([] (num_domains_to_ephe_sweep == 0)) }
ltl p2 { <> ([] ephe_sweep) }
ltl p3 { [] (ephe_cycle_in_domain[0] <= ephe_cycle) }
ltl p4 { [] (ephe_sweep -> num_domains_to_mark == 0) }
ltl p5 { [] (ephe_sweep -> ephe_cycle_in_domain[0] == ephe_cycle) }

proctype major_slice (byte did) {
  bool sweep_done = false;
  bool mark_done = false;
  int saved_ephe_cycle;
  bool ephe_sweep_done = false;

  //To model that there is a fixed amount of marking to do.
  int ephemeron_depth = EPHEMERON_DEPTH;
  byte i;
  bool done = false;


  assert (num_domains_to_mark >= 0);
  assert (num_domains_to_sweep >= 0);
  assert (num_domains_to_ephe_sweep >= 0);
  assert (ephemeron_depth >= 0);

  if
  :: !sweep_done -> {
      //Do sweep
      atomic { num_domains_to_sweep--; };
      sweep_done = true
     }
  :: else
  fi;

  again:
  if
  :: !mark_done -> {
      //Do mark
      atomic { ephe_cycle++ };
      atomic { num_domains_to_mark--; };
      mark_done = true;
     }
  :: else
  fi;

  if
  :: num_domains_to_sweep == 0 &&
     num_domains_to_mark == 0 -> {
       if
       :: ephe_cycle > ephe_cycle_in_domain[did] ->
             saved_ephe_cycle = ephe_cycle;
             if //epheMark
             :: ephemeron_depth > 0 ->
                 atomic { num_domains_to_mark++; };
                 mark_done = false;
                 ephemeron_depth--;
                 goto again
             :: else
             fi;
             if
             :: mark_done ->
                 ephe_cycle_in_domain[did] = saved_ephe_cycle;
             :: else
             fi
       :: else
       fi
     }
  :: else
  fi;

  if
  :: num_domains_to_sweep == 0 &&
     num_domains_to_mark == 0 &&
     !ephe_sweep -> {
        saved_ephe_cycle = ephe_cycle;
        i = 0;
        do
        :: i < N ->
            if
            :: saved_ephe_cycle != ephe_cycle_in_domain[i] -> break
            :: else
            fi;
            i++
        :: i == N -> break
        od;
        if
        :: i == N && saved_ephe_cycle == ephe_cycle ->
            ephe_sweep = true
        :: else
        fi;
     }
  :: else
  fi;

  if
  :: ephe_sweep -> {
    if
    :: !ephe_sweep_done ->
          ephe_sweep_done = 1;
          atomic { num_domains_to_ephe_sweep--; }
    :: else
    fi;
    //wait for other domains to finish ephe_sweep
    (num_domains_to_ephe_sweep == 0) -> done = true
  }
  // wait for some domain to finish marking
  :: else -> (num_domains_to_mark == 0) -> goto again
  fi;

  assert (ephe_cycle > 0);
  assert (done)
}

init {
  byte i = 0;

  num_domains_to_mark = N;
  num_domains_to_sweep = N;
  num_domains_to_ephe_sweep = N;
  ephe_cycle = 0;
  ephe_sweep = false;

  do
  :: i < N ->
       ephe_cycle_in_domain[i] = 0;
       i++;
  :: i == N -> break
  od;

  atomic {
    i = 0;
    do
    :: i < N ->
        run major_slice(i);
        i++;
    :: i == N ->
        break;
    od
  }
}
