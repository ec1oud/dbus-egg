(import (prefix dbus dbus:) (chicken pretty-print))

(define ctxt (dbus:make-context
	service: 'org.openmoko.PhoneKit
	interface: 'org.freedesktop.DBus.Introspectable
	path: '/org/openmoko/PhoneKit/Dialer))

(let ([response (dbus:call ctxt "Introspect")])
	(pretty-print response)
)

(exit)
