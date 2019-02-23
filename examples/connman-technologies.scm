(import (prefix dbus dbus:) (chicken pretty-print))

(define ctxt (dbus:make-context
				;bus: dbus:system-bus
				service: 'net.connman
				interface: 'net.connman.Manager))

(pp (dbus:call ctxt "GetTechnologies"))
