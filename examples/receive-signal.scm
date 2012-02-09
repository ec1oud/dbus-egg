(use (prefix dbus dbus:))

(define (signal . parms) (printf "got signal ~s~%" parms))

(define ctxt (dbus:make-context	interface: 'language.english path: '/humanity))

(dbus:register-signal-handler ctxt "hey" signal)
