;; This is quite an incomplete simulator of course;
;; it only provides a couple of dbus methods with hard-coded responses
;; which you can test with connman-ethernet.scm, connman-technologies.scm
;; and relevant parts of introspect-connman.scm

(use (prefix dbus dbus:))

(define ethernet-props
	`(#(("Type" . ,(dbus:make-variant "ethernet"))
	   ("Security" . ,(dbus:make-variant))
	   ("State" . ,(dbus:make-variant "online"))
	   ("Favorite" . ,(dbus:make-variant #t))
	   ("Immutable" . ,(dbus:make-variant #f))
	   ("AutoConnect" . ,(dbus:make-variant #f))
	   ("Name" . ,(dbus:make-variant "Wired"))
	   ("LoginRequired" . ,(dbus:make-variant #f))
	   ("Ethernet" . ,(dbus:make-variant
		`#(("Method" . ,(dbus:make-variant "auto"))
		  ("Interface" . ,(dbus:make-variant "eth0"))
		  ("Address" . ,(dbus:make-variant "C8:0A:A9:DA:AE:A5"))
		  ("MTU" . ,(dbus:make-variant 1500)))))
	   ("IPv4" . ,(dbus:make-variant
		`#(("Method" . ,(dbus:make-variant "dhcp"))
		  ("Address" . ,(dbus:make-variant "10.0.0.148"))
		  ("Netmask" . ,(dbus:make-variant "255.255.255.0")))))
	   ("IPv4.Configuration" . ,(dbus:make-variant `#(("Method" . ,(dbus:make-variant "dhcp")))))
	   ("IPv6" . ,(dbus:make-variant))
	   ("IPv6.Configuration" . ,(dbus:make-variant `#(("Method" . ,(dbus:make-variant "auto")) ("Privacy" . ,(dbus:make-variant "disabled")))))
	   ("Nameservers" . ,(dbus:make-variant '#("10.0.0.1")))
	   ("Nameservers.Configuration" . ,(dbus:make-variant))
	   ("Domains" . ,(dbus:make-variant '#("lan")))
	   ("Domains.Configuration" . ,(dbus:make-variant))
	   ("Proxy" . ,(dbus:make-variant `#(("Method" . ,(dbus:make-variant "direct")))))
	   ("Proxy.Configuration" . ,(dbus:make-variant))
	   ("Provider" . ,(dbus:make-variant)))) )

(define manager-techs
`(#(,(dbus:make-struct (dbus:string->object-path "/net/connman/technology/wifi")
     `#(("Name" . ,(dbus:make-variant "WiFi"))
       ("Type" . ,(dbus:make-variant "wifi"))
       ("Powered" . ,(dbus:make-variant #f))
       ("Connected" . ,(dbus:make-variant #f))
       ("Tethering" . ,(dbus:make-variant #f))))
   ,(dbus:make-struct (dbus:string->object-path "/net/connman/technology/bluetooth")
     `#(("Name" . ,(dbus:make-variant "Bluetooth"))
       ("Type" . ,(dbus:make-variant "bluetooth"))
       ("Powered" . ,(dbus:make-variant #f))
       ("Connected" . ,(dbus:make-variant #f))
       ("Tethering" . ,(dbus:make-variant #f))))
   ,(dbus:make-struct (dbus:string->object-path "/net/connman/technology/ethernet")
     `#(("Name" . ,(dbus:make-variant "Wired"))
       ("Type" . ,(dbus:make-variant "ethernet"))
       ("Powered" . ,(dbus:make-variant #t))
       ("Connected" . ,(dbus:make-variant #t))
       ("Tethering" . ,(dbus:make-variant #f)))))))

(define ethernet-ctxt (dbus:make-context
	; bus: dbus:system-bus
	service: 'net.connman
	interface: 'net.connman.Service
	path: '/net/connman/service/ethernet_c80aa9daaea5_cable))

(define mgr-ctxt (dbus:make-context
	service: 'net.connman interface: 'net.connman.Manager))

(define (props-query . params)
	(printf "got a props-query; params: ~s returning~%" params) (pp ethernet-props)
	ethernet-props)
(dbus:register-method ethernet-ctxt "GetProperties" props-query)

; (define (techs-query . params)
	; (printf "got a techs-query; params: ~s returning~%" params) (pp manager-techs)
	; manager-techs)
(dbus:register-method mgr-ctxt "GetTechnologies" (lambda params manager-techs))

(let loop ()
	; (printf "poll~%")
	(dbus:poll-for-message bus: dbus:session-bus)
	; (dbus:poll-for-message dbus:system-bus)
	(loop))
