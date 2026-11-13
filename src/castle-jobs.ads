with System.Multiprocessors;

--  Worker threads for batch work (world creation, previews).  The runtime
--  job system (streaming chunk generation, meshing, lighting, saving) will
--  live beside this as a persistent pool fed by a protected priority queue;
--  the main simulation thread never blocks on either.
package Castle.Jobs is

   Worker_Count : Positive := Positive (System.Multiprocessors.Number_Of_CPUs);
   --  Override before use, e.g. CPUs - 1 to keep the main thread free.

   generic
      with procedure Process (Index : Integer);
   procedure Parallel_For (First, Last : Integer; Grain : Positive := 1);
   --  Calls Process for every index in First .. Last, spread over
   --  Worker_Count Ada tasks in blocks of Grain indices.  Returns when every
   --  call has finished and re-raises the first exception any worker hit.
   --  Process must only write state that no other index writes.

end Castle.Jobs;
