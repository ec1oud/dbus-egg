(use (prefix dbus dbus:))

(define ctxt (dbus:make-context
	bus: dbus:system-bus
	service: 'org.freedesktop.Avahi
	; path: '/	;; by default is '/ anyway
))

(let ([response (dbus:discover-api-xml ctxt)])
	(display response)
)

(exit)
