(use (prefix dbus dbus:))
(dbus:auto-unbox-variants #t)
(dbus:auto-unbox-structs #t)
(dbus:auto-unbox-object-paths #t)
(define (signal . parms) (pp parms))

(define dbctxt (dbus:make-context
	bus: dbus:system-bus
	interface: 'org.freedesktop.DBus
	service: 'org.freedesktop.DBus
	path: '/org/freedesktop/DBus))
(dbus:register-signal-handler dbctxt "NameAcquired"  (lambda (msg) (printf "NameAcquired ~a~%" msg)))

(define ctxt (dbus:make-context bus: dbus:system-bus interface: 'net.connman.Manager))
(dbus:register-signal-handler ctxt "ServicesChanged" signal)
(dbus:register-signal-handler ctxt "PropertyChanged" signal)
