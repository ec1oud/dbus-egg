;; What do you get when you merge a remote-control car
;; with a supercomputer capable of deep thought?
;; A paranoid android!
;; Well actually it should walk rather than roll...
;; but the remote-control API can still be the same

(use (prefix dbus dbus:))

(define (turn-right) (printf "rolls eyes and turns to the right~%"))
(define (turn-left) (printf "rolls eyes and turns to the left~%"))

(define (query . params)
	(printf "got some sort of banal query; params: ~s~%" params)
	;; the response to the query:
	`(#t 42))

(define rc-car-context (dbus:make-context
	service: 'com.trolltech.CarExample
	path: '/Car
	interface: 'com.trolltech.Examples.CarInterface ))

(define query-context (dbus:make-context
	service: 'test.method.server
	interface: 'test.method.Type
	path: '/test/method/Object))

(dbus:register-method query-context "Method" query)
(dbus:register-method rc-car-context "turnRight" turn-right)
(dbus:register-method rc-car-context "turnLeft" turn-left)
