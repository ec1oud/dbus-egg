;; example by Mario Goulart to monitor DeviceAdded notification from udisks daemon
;; this uses the older API; udisks2 is different
(use extras dbus)

;; dbus returns #(#<unsupported-type >) to represent empty container
;; values
(define (empty-dbus-value? val)
  (and (vector? val)
       (> (vector-length val) 0)
       (unsupported-type? (vector-ref val 0))))

(define (dbus-value property properties)
  (let ((val (alist-ref property properties equal?)))
    (cond ((empty-dbus-value? val)
           value-not-set)
          ((variant? val)
           (let ((data (variant-data val)))
             (if (empty-dbus-value? data)
                 value-not-set
                 data)))
          (else val))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define udisks-context
  (make-context
   bus: system-bus
   interface: 'org.freedesktop.UDisks
   service: 'org.freedesktop.UDisks
   path: '/org/freedesktop/UDisks))

(define (handle-new-device object-path)
  (let* ((dev-ctx (make-context
                   bus: system-bus
                   interface: 'org.freedesktop.DBus.Properties
                   service: 'org.freedesktop.UDisks
                   path: (object-path->string object-path)))
         (props/vals
          (vector->list
           (car (call dev-ctx "GetAll" "org.freedesktop.UDisks.Device"))))
         (drive-model (dbus-value "DriveModel" props/vals))
         (device-file (dbus-value "DeviceFile" props/vals))
         (removable? (dbus-value "DeviceIsRemovable" props/vals))
         (fs? (dbus-value "IdUsage" props/vals))
         (fs-type (dbus-value "IdType" props/vals))
         (media-available? (dbus-value "DeviceIsMediaAvailable" props/vals))
         (partition? (dbus-value "DeviceIsPartition" props/vals))
         (partition-label (dbus-value "PartitionLabel" props/vals))
         (partition-number (dbus-value "PartitionNumber" props/vals)))

    (print "====================================================================================")
    (pp `((drive-model ,drive-model)
          (device-file ,device-file)
          (removable?  ,removable?)
          (fs?         ,fs?)
          (fs-type     ,fs-type)
          (media-available? ,media-available?)
          (partition?  ,partition?)
          (partition-label ,partition-label)
          (partition-number ,partition-number)))
    (print "====================================================================================")
    ))

(register-signal-handler udisks-context
                         "DeviceAdded"
                         handle-new-device)

(enable-polling-thread! bus: system-bus enable: #f)

(let loop ()
  (poll-for-message bus: system-bus timeout: 100)
  (loop))
