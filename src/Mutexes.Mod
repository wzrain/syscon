(* Runtime support for Mutexes *)

MODULE Mutexes;

IMPORT Activities, Queues, Counters, Processors;

(** Represents a synchronization object which acquires mutually exclusive access to shared resources. *)
TYPE 
	Mutex* = RECORD
		owner {UNTRACED} := NIL: Activities.Activity; (* stores the activity that has currently acquired the mutex, or NIL if it is not acquired *)
		mq: Queues.Queue ;
	END;

(*PROCEDURE Enqueue(previous {UNTRACED}: Activities.Activity; queue {UNTRACED}: POINTER {UNSAFE} TO Queues.Queue);
BEGIN{UNCOOPERATIVE, UNCHECKED}
	Queues.Enqueue(previous, queue^);
END Enqueue;*)
PROCEDURE Enqueue(previous {UNTRACED}: Activities.Activity; mutex {UNTRACED}: POINTER {UNSAFE} TO Mutex);
VAR item: Queues.Item;
BEGIN{UNCOOPERATIVE, UNCHECKED}
	Queues.Enqueue(previous, mutex.mq);
	IF CAS (mutex.owner, NIL, NIL) = NIL THEN
		IF Queues.Dequeue (item, mutex.mq) THEN Activities.Resume (item(Activities.Activity)) END;
	END;
END Enqueue;

(** Acquires mutual exclusive access to shared resources that are associated with a mutex. *)
(** If the mutex is currently acquired by some other activity, this procedure waits until it gets exclusive access to it. *)
PROCEDURE Acquire- (VAR mutex: Mutex);
VAR currentActivity {UNTRACED}, nextActivity: Activities.Activity;
BEGIN
	currentActivity := Activities.GetCurrentActivity ();
	(*LOOP
		IF CAS(mutex.owner, NIL, currentActivity) = NIL THEN
			EXIT;
		END;
	END;*)
	WHILE CAS(mutex.owner, NIL, currentActivity) # NIL DO
		IF Activities.Select(nextActivity, Activities.IdlePriority) THEN
			(*Activities.SwitchTo(nextActivity, Enqueue, ADDRESS OF mutex.mq);*)
			Activities.SwitchTo(nextActivity, Enqueue, ADDRESS OF mutex);
			Activities.FinalizeSwitch;
		ELSE
			Enqueue(currentActivity, ADDRESS OF mutex.mq);
		END;
	END;
END Acquire;


PROCEDURE SetOwner(previous {UNTRACED}: Activities.Activity; mutex {UNTRACED}: POINTER {UNSAFE} TO Mutex);
VAR currentActivity : Activities.Activity;
BEGIN 
	currentActivity := Activities.GetCurrentActivity ();
	ASSERT(CAS(mutex.owner, previous, currentActivity) = previous);
END SetOwner;

(** Releases the mutual exclusive access to shared resources that are associated with a mutex. *)
(** This procedure must be called once after each corresponding call to the Mutexes.Acquire procedure. *)
(** A mutex may not be released if it was not acquired by the same activity beforehand. *)
PROCEDURE Release- (VAR mutex: Mutex);
VAR currentActivity {UNTRACED}: Activities.Activity; 
VAR item : Queues.Item;
BEGIN
	currentActivity := Activities.GetCurrentActivity ();
	(* reset the owner and check for consistency *)
	(*LOOP	
		IF CAS(mutex.owner, currentActivity, NIL) = currentActivity THEN EXIT END;
	END*)
	(*IF Queues.Dequeue(item, mutex.mq) THEN
		Activities.SwitchTo(item(Activities.Activity), SetOwner, ADDRESS OF mutex);
		Activities.FinalizeSwitch;
		Activities.Resume(currentActivity);
	ELSE 
		ASSERT(CAS(mutex.owner, currentActivity, NIL) = currentActivity);
	END;*)
	ASSERT(CAS(mutex.owner, currentActivity, NIL) = currentActivity);
	IF Queues.Dequeue(item, mutex.mq) THEN Activities.Resume(item(Activities.Activity)) END;
END Release;

END Mutexes.
