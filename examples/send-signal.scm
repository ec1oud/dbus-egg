(use (prefix dbus dbus:))

(define ctxt (dbus:make-context	interface: 'language.english path: '/humanity))

(dbus:send ctxt "hey" "so long and thanks for all the fish")
(exit)
