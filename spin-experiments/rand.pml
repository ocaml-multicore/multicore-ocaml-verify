#define RANGE 8


active proctype randnr() {
	byte counter = 0;
  do
	:: (counter != 255) -> counter++
	:: (counter !=0) -> counter--
	:: break
	od;
	printf ("counter: %d\n", counter);
	assert (counter != 128);
}
