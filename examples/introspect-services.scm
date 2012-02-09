(use (prefix dbus dbus:))

;; the actual dbus call to get known service names:
; (define ctxt (dbus:make-context
	; service: 'org.freedesktop.DBus
	; interface: 'org.freedesktop.DBus
	; path: '/org/freedesktop/DBus
	; ))

; (let ([response (dbus:call ctxt "ListNames")])
	; (display response)
; )

;; dbus.egg provides this:
(printf "session bus services:~%")
(pretty-print (dbus:discover-services))	;; session bus by default
(printf "system bus services:~%")
(pretty-print (dbus:discover-services bus: dbus:system-bus))

(exit)
