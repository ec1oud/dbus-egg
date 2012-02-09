(use (prefix dbus dbus:))

(define (turn-right) (printf "car is turning to the right~%"))
(define (turn-left) (printf "car is turning to the left~%"))

(define rc-car-context (dbus:make-context
	; bus: dbus:session-bus 	;; would be the session-bus by default anyway
	service: 'com.trolltech.CarExample
	path: '/Car
	interface: 'com.trolltech.Examples.CarInterface ))

(dbus:enable-polling-thread!
	; bus: dbus:session-bus 	;; would be the session-bus by default anyway
	enable: #f)

(dbus:register-method rc-car-context "turnRight" turn-right)
(dbus:register-method rc-car-context "turnLeft" turn-left)

(let loop ()
	; (printf "poll~%")
	; (dbus:poll-for-message bus: dbus:session-bus)	;; would be the session-bus by default anyway
	(dbus:poll-for-message)
	(loop))
