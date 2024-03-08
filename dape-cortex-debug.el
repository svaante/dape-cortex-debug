;;; dape-cortex-debug.el -- Cortex debug adapter for dape -*- lexical-binding: t -*-

;; Author: Daniel Pettersson
;; Maintainer: Daniel Pettersson <daniel@dpettersson.net>
;; Created: 2023
;; Homepage: https://github.com/svaante/dape-cortex-debug

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a `dape-configs' entry for cortex-debug
;; adapter.  cortex-debug is an adapter for debugging embedded
;; devices.  Currently only jlink debugging is supported, that is not
;; an limitation of cortex-debug, but of this package.

;; The main reason for this not being included in `dape' proper is
;; that cortex-debug might be the quirkiest of adapters.  To be able
;; to debug with jlink cortex-debug requires an running tcp socket to
;; send gdb console output to, if this service is not available the
;; adapter will crash on startup.
;; See `dape-cortex-debug--config-gdb-console'.

;; This package is not package as part of `dape' as it will
;; hopefully be deprecated as soon as arm-none-eabi is built with GDB
;; version 14.1.  This might be re-evaluated at a later point.

;; See <https://github.com/Marus/cortex-debug> for adapter releases
;; and information.
;; See `dape-cortex-debug-directory' for installation.

;; Usage:
;; (require 'dape-cortex-debug)

;;; Code:
(require 'dape)

(defgroup dape-cortex-debug nil
  "Cortex debug adapter for `dape'."
  :group 'dape)

(defcustom dape-cortex-debug-directory
  (file-name-concat dape-adapter-dir "cortex-debug")
  "Directory of cortex debug extension.
Directory containing cortex-debug extension."
  :type 'directory
  :group 'dape-cortex-debug)

(defvar-local --gdb-console-process nil)

(defun --config-gdb-console (config)
  "Start tcp server and enrich CONFIG with server's port.
Is an `dape-configs' `fn' function."
  (pcase-let* (((map (:gdbServerConsolePort port :autoport)) config)
               ;; HACK Use `dape-config-autoport' to get free port
               ;;      for console
               ((map ('port port)) (dape-config-autoport `(port ,port)))
               ;; Reuse \\*dape- naming scheme to kill buffer on
               ;; `dape-quit'
               (buffer (get-buffer-create "*dape-GDB console*")))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer))
      (shell-mode)
      (unless (and (processp --gdb-console-process)
                   (process-live-p --gdb-console-process))
        (setq --gdb-console-process
              (make-network-process
               :name "*dape cortex-debug GDB console*"
               :server t
               :host 'local
               :filter (lambda (proc string)
                         (set-process-buffer proc (process-contact proc :buffer))
                         (ignore-errors (comint-output-filter proc string)))
               :service port
               :noquery t
               :buffer buffer)))
      ;; HACK Use `dape--display-buffer' to display buffer
      (dape--display-buffer (current-buffer))
      (plist-put config :gdbServerConsolePort
                 (process-contact --gdb-console-process :service)))))

(defun --config-defaults (config)
  "Enrich CONFIG with defaults required by cortex-debug.
Is an `dape-configs' `fn' function."
  `(,@config
    :pvtAvoidPorts []
    :chainedConfigurations (:enabled nil)
    :debuggerArgs []
    :swoConfig (:enabled
                nil
                :decoders []
                :cpuFrequency 0
                :swoFrequency 0
                :source "probe")
    :rttConfig (:enabled nil :decoders [])
    :graphConfig []
    :preLaunchCommands []
    :postLaunchCommands []
    :preAttachCommands []
    :postAttachCommands []
    :preRestartCommands []
    :postRestartCommands []
    :preResetCommands []
    :postResetCommands []
    :interface "swd"
    :toolchainPath :null
    :toolchainPrefix "arm-none-eabi"
    :objdumpPath :null
    :extensionPath ,dape-cortex-debug-directory
    :registerUseNaturalFormat t
    :variableUseNaturalFormat t
    :pvtVersion "1.10.0"))

;; Add jlink configuration to `dape-configs'
(add-to-list 'dape-configs
             `(cortex-debug-jlink
               command "node"
               command-args (,(expand-file-name
                               (file-name-concat
                                dape-cortex-debug-directory
                                "dist" "debugadapter.js")))
               fn (,'--config-gdb-console ,'--config-defaults)
               :type "cortex-debug"
               :request "launch"
               :servertype "jlink"
               :device "cortex"
               :cwd dape-cwd
               :executable "a.out"
               :runToEntryPoint :null
               :gdbPath :null
               :serverpath :null
               :rtos :null))

(provide 'dape-cortex-debug)
;;; dape-cortex-debug.el ends here

;; Local Variables:
;; read-symbol-shorthands: (("--" . "dape-cortex-debug--"))
;; End:
