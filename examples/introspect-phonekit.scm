(use (prefix dbus dbus:))

(define ctxt (dbus:make-context
	service: 'org.openmoko.PhoneKit
	interface: 'org.freedesktop.DBus.Introspectable
	path: '/org/openmoko/PhoneKit/Dialer))

(let ([response (dbus:call ctxt "Introspect")])
	(pretty-print response)
)

(exit)
