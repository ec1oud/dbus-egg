(use (prefix dbus dbus:))

(define ctxt (dbus:make-context
				;bus: dbus:system-bus
				service: 'net.connman
				interface: 'net.connman.Manager))

(pp (dbus:call ctxt "GetTechnologies"))
