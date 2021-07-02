(import
  (chicken format)
  (chicken pathname)
  (chicken process-context)
  (chicken process signal)
  (chicken time)
  (prefix dbus dbus:)
  scsh-process
  srfi-13
  srfi-18
  test)

(define shared-variable-mutex (make-mutex))
(define server-started (make-parameter #f))
(define server-stopped #f)
(define under-dbus "RUNNING_UNDER_DBUS")
(define dbus-client "DBUS_CLIENT")
(define dbus-server "DBUS_SERVER")
(define dbus-test-context
  (dbus:make-context
   bus: dbus:session-bus
   interface: 'org.call_cc.dbus_egg.Tests
   service: 'org.call_cc.dbus_egg.tests
   path: '/org/call_cc/dbus_egg/TestsObject))
(define dbus-signal-context
  (dbus:make-context
   bus: dbus:session-bus
   interface: 'language.english
   path: '/org/call_cc/dbus_egg/TestsObject))

(define (tcall method . params)
  (apply dbus:call (cons dbus-test-context (cons method params))))

(define (cleanup-process process #!key (tries 15))
  (if (= tries 0)
      (begin
	(signal-process process signal/kill)
	(wait process))
      (begin
	(when (not (wait process #t))
	  (sleep 1)
	  (cleanup-process process tries: (sub1 tries))))))

(define (reexec-with-dbus-session)
  (set-environment-variable! under-dbus "1")
  (exec-epf (dbus-run-session -- ,@(argv))))

(define (dbus-call-test local-method remote-method . params)
  (test (apply local-method params) (car (apply tcall remote-method params))))

(define (start-handler . params)
  (server-started #t))

(define (run-client-tests)
  (dbus-call-test expt "expt" 30 6)
  (dbus-call-test + "plus" 9723 1459)
  (dbus-call-test string-reverse "StringReverse" "hello there"))

(define (do-client-interaction)
  (let ((wait-start (current-milliseconds)))
    (let loop ()
      (when
	  (and
	   (not (server-started))
	   (< (- (current-milliseconds) wait-start) 60000))
	(dbus:poll-for-message bus: dbus:session-bus timeout: 500) (loop)))
    (if (server-started)
	(run-client-tests)
	(error 'do-client-interaction "Service unavailable."))))

(define (for-each-pair proc pair-list)
  (when (not (null? pair-list))
    (let ((pair (car pair-list)))
      (proc (car pair) (cdr pair)))
    (for-each-pair proc (cdr pair-list))))

(define (with-shared-variable-mutex thunk)
  (dynamic-wind
    (lambda () (mutex-lock! shared-variable-mutex))
    thunk
    (lambda () (mutex-unlock! shared-variable-mutex))))

(define (server-is-stopped)
  (with-shared-variable-mutex (lambda () server-stopped)))

(define (do-server)
  (for-each-pair
   (cut dbus:register-method dbus-test-context <> <>)
   `(
     ("expt" . ,(lambda (x y) (list (expt x y))))
     ("plus" . ,(lambda (x y) (list (+ x y))))
     ("StringReverse" . ,(lambda (x) (list (string-reverse x))))
     ("stop" . ,(lambda () (with-shared-variable-mutex (lambda () (set! server-stopped #t))) '()))))
  (dbus:send dbus-signal-context "ServerStarted" #t)
  (let loop ()
    (when (not (server-is-stopped)) (sleep 1) (loop))))

(define (main args)
  (when (not (get-environment-variable under-dbus))
    (reexec-with-dbus-session))
  (when
      (get-environment-variable dbus-server)
    (do-server)
    (exit 0))

  (dbus:register-signal-handler dbus-signal-context "ServerStarted" start-handler)
  (set-environment-variable! dbus-server "1")
  (let ((server-process (& (,(car (argv)) ,@(cdr (argv))))))
    (test-begin "dbus")
    (test-group "Method Calls")
    (dynamic-wind
      void
      do-client-interaction
      (lambda ()
	(tcall "stop")
	(cleanup-process server-process)))
    (test-end)
    (when (not (server-started)) (exit 1))
    (test-exit)))

(when (not (string=? (pathname-file (program-name)) "csi"))
  (main (command-line-arguments)))
