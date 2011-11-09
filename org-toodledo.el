;;; org-toodledo.el - Toodledo integration for Emacs Org mode
;;
;; (c) 2011 Christopher J. White (cjwhite -- emacs <at> grierwhite.com)
;; GNU General Public License v2 (GNU GPL v2),
;; inspired by work from Sacha Chua
;;
;; This file is not part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
;; MA 02111-1307, USA.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Commentary
;;
;; This package is adds the ability to sync org-mode tasks with
;; Toodledo, a powerful web-based todo list manager that welcomes 3rd
;; party integrations.  (See http://www.toodledo.com/)
;;
;; This version of `org-toodledo' utilizes version 2.0 of the Toodledo API. 
;;
;; INSTALLATION
;; ------------
;;
;; 1. Required emacs packages:
;;      * `w3m' or `w3mexcerpt' -- see Notes below
;;      * `http-post-simple' -- http://www.emacswiki.org/emacs/http-post-simple.el
;;
;; 2. Put this file in your load path, byte compile the file for best
;;    performance, see `byte-compile-file'.
;;
;; 3. Put the following in your .emacs:
;;
;;    (push "<path-to-this-file>" load-path)
;;    (require 'org-toodledo)
;;    (setq org-toodledo-userid "<toodledo-userid>")      << *NOT* your email!
;;    (setq org-toodledo-password "<toodled-password>")
;;
;;    ;; Useful key bindings for org-mode
;;    (add-hook 'org-mode-hook
;;           (lambda ()
;;             (local-unset-key "\C-o")
;;             (local-set-key "\C-od" 'org-toodledo-mark-task-deleted)
;;             (local-set-key "\C-os" 'org-toodledo-sync)
;;             )
;;           )
;;
;; SYNCHRONIZING FOR THE FIRST TIME
;; --------------------------------
;;
;; The first step in using org-toodledo is to initialize a file and
;; synchronize tasks.  Simply create a new file, change the mode to
;; `org-mode', then call `org-toodledo-initialize'.  This will create
;; a new heading called "TASKS" (by default) and will import all
;; non-deleted tasks from Toodledo as sub-headings beneath "TASKS".
;;
;; If you already have an existing list of tasks in org file, open the
;; org file first.  Move the cursor to the headling where you want
;; imported tasks from Toodledo to be inserted into the buffer.  Call
;; `org-toodledo-initialize'.  This will import all tasks from the
;; server as well as pushing existing tasks in the org file back to
;; the server.
;; 
;; Once an org-file has been initialized, the heading selected will
;; be given a few Toodledo specific properties that are used to track
;; the status of synchronization:
;;
;;   * TASKS 
;;     :PROPERTIES:
;;     :ToodledoLastSync: 1315343842
;;     :ToodledoLastEdit: 1315337478
;;     :ToodledoLastDelete: 1314972230
;;     :END:
;;
;; This is referred to as the 'base Toodledo entry'.
;;
;; SYNCHRONIZING TASKS
;; -------------------
;;
;; The local org-file can be synchronized with the server at any time
;; by calling `org-toodledo-sync'.  When called, the following steps
;; are performed:
;; 
;;   1. Tasks added to the server since the last sync are downloaded
;;      and inserted as sub-headings to the Toodledo base heading (has
;;      the `ToodledoLastSync' property)
;;
;;   2. Tasks modified on the server are compared against the local
;;      copy.  If the local copy was not modified since the last sync,
;;      the local copy is updated.  If local copy was modified, the
;;      server copy is inserted *after* the local copy as a duplicate.
;;      The user must manually merge any changes
;;
;;   3. Tasks deleted on the server are removed entirely from the
;;      local org file.
;;
;;   4. Tasks modified locally are pushed to the server as edits.
;;
;;   5. Tasks created and not yet prseent on the server are pushed as
;;      new tasks.
;;
;;   6. Tasks marked for deletion are deleted from the server, and
;;      then purged from the local file.
;;
;; Changes to tasks are automatically detected by computing a hash of
;; the task fields.  This hash is computed and saved as a property of
;; the task on sync.  When the next sync occurs, the hash value is
;; compared and if it differs, the task is considered modified.  This
;; eliminates the need for the user to mark tasks as modified or
;; remembere which tasks have changed -- it's all automatic!
;;
;; Note that `org-toodledo-sync' scans the entire file for tasks, not
;; just subheadings of the base entry.
;;
;; ADDING NEW TASKS
;; ----------------
;;
;; To add a new task on the server, just create a new headline
;; anywhere in the org file and give the headline a TODO keyword.
;; When ready, call `org-toodledo-sync' to push new tasks to the
;; server.
;;
;; DELETING TASKS
;; --------------
;;
;; Tasks cannot simply be killed from the org-file like text if the
;; were already synced with the server since they will just come back
;; the next time `org-toodledo-sync' is called.  Instead, they must be
;; marked as deleted by calling `org-toodledo-mark-task-deleted'.  Call
;; this function from any point within the task.  At the next sync, 
;; the task will be deleted from the server and then killed from the 
;; local file.
;;
;; Note that it may not be necessary to delete tasks in this way.  Instead
;; complete the task and let Toodledo archive completed tasks.
;;
;; TOODLEDO FIELDS
;; ---------------
;;
;; The table lists the possible Toodledo fields and how they are
;; mapped to org-mode style tasks:
;;
;; | Toodledo Field | Org-mode               | Comments                                     |
;; | id             | Property :ToodledoID:  | If present, this task was previoiusly synced |
;; | title          | Heading                | Heading minus TODO state, priority and tags  |
;; | status         | TODO state             | See `org-toodledo-status-to-org-map'         |
;; | startdate      | SCHEDULED              |                                              |
;; | duedate        | DEADLINE               |                                              |
;; | completed      | CLOSED                 | Timestamp when the task was marked completed |
;; | repeat         | Repeat interval        |                                              |
;; | repeatfrom     |                        |                                              |
;; | context        | Tag                    | Context string "Work" becomes a tag :@Work:  |
;; | modified       | Property :Modified:    | Timestamp when last modifed (set by server)  |
;; | folder         | Property :Folder:      |                                              |
;; | goal           | Property :Goal:        |                                              |
;; | priority       | Priority               | 3=>A, 2=>B, 1=>C, -1,0 => D                  |
;; | note           | Body                   | Body of the task minus the properties        |
;; | length         | Effort                 |                                              |
;;
;; TODO STATES
;; -----------
;;
;; The TODO states from Toodledo are mapped to org-mode states via the
;; `org-toodledo-status-to-org-map' alist.   This can be customized to
;; choose your own TODO states, but all 10 states from Toodledo should
;; be mapped, even if only a subset are used in org-mode.
;;
;; In order to cycle through all the states recognized by Toodledo,
;; put a line like the following somewhere in your org file:
;;
;;   #+SEQ_TODO: TODO(t) DELEGATED(g) SOMEDAY(s) WAITING(w) | DONE(d) CANCELLED(c) REFERENCE(r) 
;;
;; CONTEXTS
;; --------
;;
;; Toodledo 'Contexts' allow you to split tasks into contexts such as
;; Work and Home.  Contexts are mapped to org tags with the '@' keyword,
;; :@Work: and :@Home:.
;;
;; Currently only contexts already on the server are recognized.  Setting
;; the task context of :@Phone: when Phone is not a valid context will 
;; loose the context.
;; 
;; SUBTASKS
;; --------
;;
;; Sub-tasks are supported by Toodledo with a Pro account subscription.  
;; When enabled, a 2-level task hierarchy is supported:
;;
;;   * TODO Write a best-selling novel
;;   ** DONE Make an outline
;;   ** WAITING Call Susan about the contract
;;   ** TODO Finish writing
;;   ** TODO Profit
;;
;; The parent/child relationship is tracked dynamically at the time
;; of sync, looking for the next heading up for each task, and if present
;; and a task, link the task to the parent.
;;
;; Bi-directional synchronization is fully supported.
;;
;; If the account is not a Pro account, subtasks will still be synced
;; to the server, but the parent/child relationship is not.  This
;; yields a flat list of tasks on the server.  Note that the hierarchy
;; in the org file is still maintained even though not on the server.
;;
;; NOTE: A 3-level hierarchy of TODO items will not work and will 
;; probably cause an error during sync.  It's no problem to use
;; a much deeper hierarchy of org items, as long as only the last
;; two are actually TODO items.
;;
;; MISCELLANEOUS NOTES
;; -------------------
;;
;;  - Doesn't do lots of error trapping. Might be a good idea to
;;    version-control your Org file.
;;
;;  - Verify handling of other tags that are not context
;;  
;;  - The body of a task is stored as the Toodledo note.  May get
;;    confused by asterisks, so don't use any starting asterisks in
;;    your body text.  (or anything that looks like an Org headline).
;;
;;  - w3mexcerpt.el inlcudes things needed things from w3m (since w3m
;;    requires things which require things which require things which
;;    require an executable which is no longer readily
;;    available.). (sachac)
;;
;;  - By default, save will ask to sync with Toodledo.  This can
;;    behavior can be changed via `org-toodledo-sync-on-save'.
;;
;; FUTURE WORK
;; -----------
;;
;; ** TODO Feature Requests: highest priority at top
;; 
;; [ ] Trap 3-levels of TODO tasks and warn the user or just flatten
;;     the list.  (cjwhite)
;;
;; [ ] Some how indicate that a task has been marked deleted.  Right now
;;     marking a task deleted puts a property in the drawer, which
;;     is hidden.  Maybe add a TODO status of DELETED?  Move to a new
;;     "DELETED" sub-heading?  (cjwhite)
;;     
;; [ ] It'd be great to allow notes to contain asterisks.  Make
;;     "[CR]** " the special key?  I use multiple asterisks all the
;;     time in notes.  (stophlong)
;; 
;; [ ] access to toodledo via proxy would also be good for those
;;     inside proxy based firewalls. (stophlong)
;; 
;; [ ] Better handling of 'duplicate' tasks -- those modified locally and
;;     on the server.  Perhaps tag them with a property and then on sync
;;     check for them asking the user to resolve. (cjwhite)
;;
;; [ ] Add a 'purge-completed-tasks' function -- once these tasks have
;;     been synced to the server, kill them locally (since they are
;;     backed up on toodledo).  Alternatively, move them to an archive
;;     file.  (cjwhite)
;;
;; [ ] Option to restrict synchronization to just tasks under the the
;;     base Toodledo entry.  (cjwhite)
;;
;; [ ] Support tasks across all agenda files.  (cjwhite)
;;
;; CHANGES
;; -------
;;
;; 2011-09-07  (cjwhite)
;; - First release for general distribution based on API 2.0
;;
;; 2011-09-18  (cjwhite)
;; - (Bug fix) Properly create contexts that are missing on the server. (cjwhite)
;; - (Bug fix) Eliminate hyphens in the tag/properties that are saved (cjwhite)
;; - Implemented sub-tasks -- requires pro account subscription (cjwhite)
;; - Added customization variable `org-toodledo-sync-import-new-tasks'
;;
;; 2011-09-24  (cjwhite)
;;
;; - Use https if pro subscription and patch installed (url-http appears broken
;;   for POSTs with data and https, at least on my box).  To enable, apply the 
;;   patch as follows:
;;       $ cd $emacs_install_dir/lisp/url
;;       $ patch < $path_to_patch/url-http.el.emacs-23.3.patch
;;   Then in emacs:
;;       M-x byte-compile-file $emacs_install_dir/lisp/url/url-http.el
;;   This patch seems to apply cleanly to 23.2 as well, but is not tested there.
;;   Search below for "bugreport" for more details and bug references.
;;
;; - Added `org-toodledo-run-tests' to load and run tests in org-toodledo-test.el.
;;   This uses the active account, creating/modifying/deleting tasks with the
;;   prefix 'ORGTOODLEDOTEST'.  All other tasks are ignored, so it *should* operate
;;   cleanly on an active toodledo account with multiple tasks.  If you run
;;   this and it does not pass all tests, please let me know  (cjwhite)
;;   
;; 2011-09-26  (cjwhite)
;; - Bug fix for checking boundp (myuhe)
;; - Support special chars (verified titles/notes) (myuhe)
;; - Added `org-toodledo-inhibit-https' to disable https
;;
;; 2011-09-29  (cjwhite)
;; - Bug fix: marking a task completed on the server did not update locally
;;
;; 2011-10-16  (cjwhite)
;; - Bug fix: first time sync of tasks with folders failed with org-mode 6.33x
;;
;; 2011-11-08  (myuhe)
;; - Bug fix for difference of timezone (myuhe)
;; - Support starttime and duetime (myuhe)
;;
;;; Code:

(require 'org)
(unless (require 'w3m nil t)
  (require 'w3mexcerpt))

(require 'xml)
(require 'json)
(require 'http-post-simple)
(require 'url)
(require 'url-http)

;;
;; User customizable variables
;;

(defcustom org-toodledo-userid ""
  "UserID from Toodledo (not your e-mail address): http://www.toodledo.com/info/api_doc.php"
  :group 'org-toodledo
  :type 'string)

(defcustom org-toodledo-password ""
  "Password for Toodledo."
  :group 'org-toodledo
  :type 'string)

(defcustom org-toodledo-sync-on-save "ask"
  "Action on save of a orgfile with toodledo tasks in it:
     no    - nothing
     ask   - ask the user to sync
     yes   - always sync"
  :group 'org-toodledo
  :type 'string
  )

(defcustom org-toodledo-sync-import-new-tasks t
  "If non-nil, import new tasks from the server, otherwise only edits
to existing tasks from the server are processed."
  :group 'org-toodledo
  :type 'boolean
  )

(defcustom org-toodledo-status-to-org-map
  '(
    ("Active" . "TODO")
    ("None" . "TODO")
    ("Next Action" . "TODO")
    ("Planning" . "TODO")
    ("Delegated" . "DELEGATED")
    ("Waiting" . "WAITING")
    ("Someday" . "SOMEDAY")
    ("Hold" . "SOMEDAY")
    ("Postponed" . "SOMEDAY")
    ("Canceled" . "CANCELED")
    ("Reference" . "REFERENCE")
    )
  "Map of Toodledo API 'status' names to org-mode TODO states."
  :group 'org-toodledo
  :type '(alist :key-type string :value-type string)
  )

(defcustom org-toodledo-sync-new-completed-tasks nil
  "When nil, new tasks downloaded from the server are not added if they
are already marked completed.  Existing tasks in the buffer are always
updated.  Set to t to sync completed tasks into the local buffer."
  :group 'org-toodledo
  :type 'boolean
  )

(defcustom org-toodledo-inhibit-https nil 
  "Set to t to inhibit the use of HTTPS even if it's available"
  :group 'org-toodledo
  :type 'boolean
)

;;
;; Internal variables for tracking org-toodledo state
;;
(defvar org-toodledo-token-expiry nil "Expiry time for authentication token.")
(defvar org-toodledo-token nil "Authentication token.")
(defvar org-toodledo-key nil "Authentication key.")
(defvar org-toodledo-pro nil "Non-nil if Toodledo account is a pro account")
(defvar org-toodledo-pro-cached nil "Non-nil means pro variable is cached")
(defvar org-toodledo-test-mode nil "Non-nil used for testing")
(defvar org-toodledo-sync-message-time 2 "Seconds to pause after displaying sync message")
(defvar org-toodledo-use-https nil "Use HTTPS for all calls.  This requires pro *and* a patched url-http.el.")
(defvar org-toodledo-debug nil "Generate debug messages")

;; Registered application ID and token for Toodledo API 2.0
(defconst org-toodledo-appid "orgtoodledo2" "Toodledo registered appid for API 2.0")
(defconst org-toodledo-apptoken "api4e4fbf7454eeb" "Toodledo apptoken associated with appid for API 2.0")

(defconst org-toodledo-fields 
  '( 
    ;; Toodledo recongized fields
    "id" "title" "status" "completed" "repeat" "repeatfrom" "context" "duedate" "duetime"
    "startdate" "starttime" "modified" "folder" "goal" "priority" "note" "length" "parent"
    ;; org-toodledo only fields
    "sync" "hash")
  "All fields related to a task"
  )

(defconst org-toodledo-fields-dont-ask
  '( 
    ;; Fields that toodled always returns, thus cannot be asked for
    "id" "title" "modified" "completed" 
    ;; org-toodledo only fields
    "sync" "hash")
  "Fields that must not be asked for from the server, either because the server
returns them automatically, or because they are internal only fields"
  )

(defconst org-toodledo-fields-dont-send
  '( 
    ;; Toodledo automatically sets modified, so don't attempt to push it
    "modified" 
    ;; org-toodledo only fields
    "sync" "hash")
  "Fields that shouldn't be sent to the server"
  )

(defconst org-toodledo-hash-fields 
  '( "title" "status" "completed" "repeat" "repeatfrom" "context" "duedate" "duetime" 
     "startdate" "starttime" "folder" "goal" "priority" "note" "length" "parent")
  "Fields that are used to compute the hash of a task for detecting when a task changed."
  )

(defvar org-toodledo-fields-ask
  (remove nil (mapcar (lambda (f) (if (member f org-toodledo-fields-dont-ask) nil f)) org-toodledo-fields))
  "Fields that can be asked for (fields minus org-toodledo-fields-dont-ask)"
  )

(defvar org-toodledo-fields-send
  (remove nil (mapcar (lambda (f) (if (member f org-toodledo-fields-dont-send) nil f)) org-toodledo-fields))
  "Fields that should be encoded and sent for new/modified tasks (fields minus org-toodled-fields-dont-send)"
  )

(defconst org-toodledo-api-status-map
  '(("0" . "None")
    ("1" . "Next Action")
    ("2" . "Active")
    ("3" . "Planning")
    ("4" . "Delegated")
    ("5" . "Waiting")
    ("6" . "Hold")
    ("7" . "Postponed")
    ("8" . "Someday")
    ("9" . "Canceled")
    ("10" . "Reference")
    )
  "Map of Toodledo API 'status' field values to names for easy reference.  The possible
values represent the keys for use in org-toodledo-status-to-org-map"
  )

(defvar org-toodledo-tmp-ref -1 
  "Temporary ID used to tag new tasks when synced in bulk to the server.  These ids 
should only be used for the short period of time when a new task is ")

;; There's a bug in url-http that seems to attempt connection reuse
;; when the connection is not valid.  This seems to only affect https
;; but just disable if set.
;;
;; See http://debbugs.gnu.org/cgi/bugreport.cgi?bug=9592
;;
(when (boundp 'url-http-inhibit-connection-reuse)
  (setq url-http-inhibit-connection-reuse t))

(defun org-toodledo-initialize (&optional default-heading)
  "Setup current item in an org file with Toodledo tasks.  If not "
  (interactive)
  (when (not (eq major-mode 'org-mode))
    (error "Toodledo initialization must be performed on an org-mode file"))

  (save-excursion
    (if (org-toodledo-goto-base-entry t)
        (message "Org-toodled already initialized")
      (let ((item default-heading)
            result)
        (unless item
          (condition-case nil
              (progn 
                (org-back-to-heading t)
                (setq item (read-from-minibuffer "Default heading for Toodledo tasks: " 
                                                 (elt (org-heading-components) 4)))
                )
            (error 
             (setq item (read-from-minibuffer "Default heading for Toodledo tasks: " "TASKS"))))
          )
        
        (when item
          (goto-char (point-min))
          (unless (re-search-forward (format "^\*+[ \t]* %s" (regexp-quote item)) nil t)
            (if (y-or-n-p (format "No heading found matching '%s', create? " item))
                (progn
                  (goto-char (point-min))
                  (insert (concat "* " item "\n"))
                  (forward-line -1)
                  )
              (error "Aborted")))

          (org-entry-put (point) "ToodledoLastSync" "0")
          (setq result (org-toodledo-sync))
          (goto-char (point-min))
          (re-search-forward (format "^\*+[ \t]* %s" (regexp-quote item)))
          (org-overview)
          (org-content)
          )
        result
        )
      )
    )
  )

(defun org-toodledo-fixup-tags ()
  "Fixup tags to eliminate the hyphen, which really shouldn't be used in tag / property names"
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "Toodledo\\(-\\)\\(lastsync\\|ID\\|lastedit_task\\|lastdelete_task\\)" nil t)
      (let ((str2 (match-string 2)))
        (replace-match "" nil nil nil 1)
        (cond
         ((string= str2 "lastsync") (replace-match "LastSync" nil nil nil 2))
         ((string= str2 "lastedit_task") (replace-match "LastEdit" nil nil nil 2))
         ((string= str2 "lastdelete_task") (replace-match "LastDelete" nil nil nil 2)))))))

;;
;; Token / key functions
;;

(defun org-toodledo-token-valid ()
  "Return if org-toodledo-token is both non-null and not expired."
  (and org-toodledo-token
       org-toodledo-token-expiry
       (time-less-p (current-time) org-toodledo-token-expiry)))

(defun org-toodledo-token ()
  "Retrieve authentication token valid for four hours.  This token is used for all 
interaction with the server.  If the token expires, a new token is automatically
retrieved. "
  (if (or (string= org-toodledo-userid "")
          (string= org-toodledo-password ""))
      (error "Please set 'org-toodledo-userid' and 'org-toodledo-password'"))

  (if (org-toodledo-token-valid)
      ;; Return cached token
      org-toodledo-token
    
    ;; Else retrieve a new token
    (let ((response
           (with-current-buffer
               (url-retrieve-synchronously
                (concat "https://api.toodledo.com/2/account/token.php?f=xml"
                        ";userid=" org-toodledo-userid
                        ";appid=" org-toodledo-appid
                        ";sig=" (md5 (concat org-toodledo-userid org-toodledo-apptoken))))
             (xml-parse-region (point-min) (point-max)))))
      (if (equal (car (car response)) 'error)
	  (progn
	    (setq org-toodledo-token nil
		  org-toodledo-key nil
		  org-toodledo-token-expiry nil)
	    (error "Could not log in to Toodledo: %s" (elt (car response) 2)))
	(setq org-toodledo-token
	      (elt (car response) 2))

        ;; Set the expiry time to 4 hours from now
        (setq org-toodledo-token-expiry
	      (seconds-to-time (+ (float-time) (* 60 60 4))))
        )
      org-toodledo-token)))

(defun org-toodledo-key ()
  "Return authentication key used for each request."
  (if (and (org-toodledo-token-valid)
           org-toodledo-key)
      ;; Return cached key
      org-toodledo-key
    ;; Recompute token and key
    (setq org-toodledo-key
          (md5 (concat (md5 org-toodledo-password)
                       org-toodledo-apptoken
                       (org-toodledo-token))))))

(defun org-toodledo-get-account-info ()
  "Return account information from server."
  (setq org-toodledo-use-https nil)
  (let ((info (org-toodledo-convert-xml-result-to-alist
               (car (org-toodledo-call-method "account/get")))))
    (setq org-toodledo-pro (string= "1" (cdr (assoc "pro" info))))
    (setq org-toodledo-pro-cached t)

    ;; The variable `url-http-inhibit-connection-reuse' was added as
    ;; part of a patch.  If it is bound, the patch was applied and
    ;; also includes a fix for adding CRLF at the end of post-data
    ;;
    ;; See http://debbugs.gnu.org/cgi/bugreport.cgi?bug=8931
    (setq org-toodledo-use-https
          (and org-toodledo-pro 
               (boundp 'url-http-inhibit-connection-reuse)
               (not org-toodledo-inhibit-https)
               ))
    
    (when org-toodledo-use-https
      (message "All interaction with toodledo.com will be via HTTPS"))
    
    info
    )
  )

(defun org-toodledo-pro ()
  (unless org-toodledo-pro-cached
    (org-toodledo-get-account-info))
  org-toodledo-pro
)
    
(defun org-toodledo-get-tasks (&optional params)
  "Retrieve tasks from server using PARAMS.
Return a list of task alists."
  (aput 'params "fields" (mapconcat 'identity org-toodledo-fields-ask ","))
  
  (mapcar
   'org-toodledo-convert-xml-result-to-alist
   (xml-get-children
    (car (org-toodledo-call-method "tasks/get" params))
    'task)))

(defun org-toodledo-get-deleted (&optional params)
  "Retrieve deleted tasks using PARAMS.
Return a list of task alists."
  (mapcar
   'org-toodledo-convert-xml-result-to-alist
   (xml-get-children
    (car (org-toodledo-call-method "tasks/deleted" params))
    'task)))

;;
;; Implementation notes on how to subtask support :
;;
;; Syncing new tasks to the server is more complex, consider all new tasks:
;;    * TASKS
;;    ** TODO Parent
;;    *** TODO Child1
;;    *** TODO Child2
;;    
;; The current sync order will attempt to create Parent, Child1, and
;; Child2 all at the same time.  Looking just for "ToodledoID" in a
;; parent heading will not work because Parent is not assigned an ID
;; until syncing with the server.
;;
;; Modified algorithm:
;; 
;;   1. Collect new-child-tasks as a separate set of tasks.  These are
;;      not all child tasks, just those whose parent is not yet synced
;;      Since tasks are processed top-down in the buffer, parents are
;;      guaranteed to be processed before children.  
;;
;;        new-child-tasks-alist:
;;            <child-tmp-ref> => <child-task-def>
;;
;;      Keep a map of all children waiting on this parent:
;;
;;        new-parent-new-child-alist: 
;;            <parent-tmp-ref> => '(list <child-tmp-ref> <child-tmp-ref>...)
;;
;;   2. Collect new-edit-tasks that were recently modified to have a
;;      parent task that is new.  
;;
;;   3. Create new-tasks first (which will include parent)
;;   
;;   4. Create new-child-tasks second, but need to find the newly assigned 
;;      parent ID
;;
;; Change scenarios
;;
;; 1. Local changes
;;    a. Add new parent task, add new child tasks
;;       - all new-tasks, the parent task will be assigned a tmp ID before children processed
;;       - children are new, but must wait for parent to get assigned a real ID
;;    b. Add new child tasks to an existing parent task (parent task *not* modified)
;;       - the parent task has no changes, child tasks are new and parent looked up by title
;;       - no hash values involved, all new tasks
;;    c. User moved existing tasks beneath a new parent task
;;       - hash value of child will change *after* the new parent task is assigned an id or tmp-ref
;;    d. Move existing child tasks beneath an existing parent
;;       - hash value of child will change due to the new relation to the parent
;;
;; 2. Remote changes
;;    a. Receive a new parent task
;;       - parent task is no different than a regular task
;;    b. Receive an edit to a task, it has a new parent
;;       - task hash will change due to parent
;;       - need to find the parent and move it there
;;    c. Receive an edit to a child task, making it a normal task (no parent)
;;       - task hash will change due to parent
;;       - need to move the task back to the normal new task folder
;;

(defun org-toodledo-sync (&optional skip-import)
  "Synchronize tasks with the server bidirectionally."
  (interactive)
  (org-toodledo-fixup-tags)
  (save-excursion
    (let* ((regexp (concat "^\\*+[ \t]+\\(" org-todo-regexp "\\)"))
           (account-info (org-toodledo-get-account-info))
           (columns-pos (if (and (boundp 'org-columns-begin-marker) org-columns-begin-marker)
                            (marker-position org-columns-begin-marker) nil))
           server-edit-tasks
           server-delete-tasks
           new-tasks
           (new-tasks-count 0)
           new-child-tasks-alist
           new-parent-new-child-alist
           edit-child-tasks-alist
           new-parent-edit-child-alist
           edit-tasks
           delete-tasks
           tasks-by-title-alist
           (end nil) ;; Restrict to Toodledo Task heading only?  XXXCJ
           )
      (when columns-pos
        (org-columns-quit))

      ;; Check for edited tasks on the server
      (unless skip-import
        (org-toodledo-goto-base-entry)
        (let ((local-lastedit-task (or (org-entry-get (point) "ToodledoLastEdit") "0")) 
              (server-lastedit-task (cdr (assoc "lastedit_task" account-info)))
              params)
          (when (> (string-to-number server-lastedit-task)
                   (string-to-number local-lastedit-task))
            (aput 'params "modafter" local-lastedit-task) ;; limit to tasks edited since last sync
            (aput 'params "comp" "-1")                    ;; grab all tasks, completed or not
            (setq server-edit-tasks (org-toodledo-get-tasks params))
            (mapc 'org-toodledo-process-task server-edit-tasks)
            )
          )
        
        ;; Check for deleted tasks on the server
        (org-toodledo-goto-base-entry)
        (let ((local-lastdelete-task (or (org-entry-get (point) "ToodledoLastDelete") "0")) 
              (server-lastdelete-task (cdr (assoc "lastdelete_task" account-info)))
              params)
          (when (> (string-to-number server-lastdelete-task)
                   (string-to-number local-lastdelete-task))
            (aput 'params "after" local-lastdelete-task) ;; limit to tasks deleted since last sync
            (setq server-delete-tasks (org-toodledo-get-deleted params))
            (mapc (lambda (task) (org-toodledo-delete-local-task (org-toodledo-task-id task))) server-delete-tasks)
            )
          )
        )

      ;;
      ;; Iterate overall TODO items in the buffer -- any item matching the todo-regexp
      ;;
      (goto-char (point-min))
      (while (re-search-forward regexp end t)

        ;; 'task' is the current state of the task at point and is parsed from the buffer
        ;; after all tasks above this point have been processed.  That means parent
        ;; tasks either have a toodledoid, or were assigned a tmp-ref
        (let* ((task (org-toodledo-parse-current-task))
               (modified (org-toodledo-task-modified task))
               (sync (org-toodledo-task-sync task))
               (hash (org-entry-get (point) "Hash"))
               (computed-hash (org-toodledo-compute-hash nil task))
               (deleted (org-entry-get (point) "Deleted"))

               ;; Find the parent task, if any -- this is not necessarily the 
               ;; task linked by parent-id (but is a toodledo task), 
               ;; this is literally the up-heading parent.  If the parent
               ;; task is new, it will have been assigned a tmp-ref by the
               ;; time its put into tasks-by-title-alist
               ;;
               ;; This parent-task is the parsed task alist.  It will have either
               ;; 'id' set if it's an existing task (known by server), or a 'ref'
               ;; if it is new waiting to be assigned a real id. 
               ;; 
               ;; Note -- subtasks require pro account subscription
               (parent-task (if (org-toodledo-pro)
                                (cdr (assoc (save-excursion (if (org-up-heading-safe)
                                                                (elt (org-heading-components) 4)))
                                            tasks-by-title-alist))))
               (parent-ref (cdr (assoc "ref" parent-task)))
               (parent-id (cdr (assoc "id" parent-task)))
               )
          (cond 
           ;; Collect a "new" task
           ;; 
           ;; A new task is any task that does not yet have an assigned Toodeldo-ID
           ((null (org-toodledo-task-id task))
            ;; Assign a temporary id, send it to the server as "ref", it will be echoed 
            ;; back from the server result with a real toodledoid.  This tmp ID is saved
            ;; in the task as the ToodledoID, but is always negative so as not to conflict
            ;; with Toodledo assigned IDs.
            (let ((tmp-ref (number-to-string (setq org-toodledo-tmp-ref (1- org-toodledo-tmp-ref))))
                  (new-task (org-toodledo-limit-fields task))
                  )
              (org-entry-put (point) "ToodledoID" tmp-ref)
              (aput 'new-task "ref" tmp-ref)
              (aput 'tasks-by-title-alist (org-toodledo-task-title task) new-task)

              (cond
               ;; No parent, not a child task, just a new task
               ((null parent-task)
                (aput 'new-task "parent" 0)
                (setq new-tasks (append new-tasks (list new-task)))
                )

               ;; New child task, but parent already is synced and has and ID
               (parent-id
                (aput 'new-task "parent" parent-id)
                (setq new-tasks (append new-tasks (list new-task)))
                )
               
               ;; New child task, but parent is also new
               (parent-ref
                ;; Save this task in new-child-task-alist for easy lookup later
                (aput 'new-child-tasks-alist tmp-ref new-task)
                
                ;; Track this child as waiting for this parent
                (aput 'new-parent-new-child-alist
                      parent-ref (append (cdr (assoc parent-ref new-parent-new-child-alist)) (list tmp-ref)))
                )

               (t (error "New task has a parent, but parent task has neither a tmp-ref nor ID"))
               )
              )
            )
           
           ;; Collect a "delete" task
           (deleted
            (setq delete-tasks (append delete-tasks (list (org-toodledo-task-id task))))
            ;; XXXCJ -- need to handle deletion of tasks that have children
            ;; This may mean leave the heading around if there are sub-headings that 
            ;; are not tasks.  
            )
           
           ;; Collect an "edit" task
           ;;
           ;; Detected by hash change.  This hash will change if any property 
           ;; of the task changed, including parent.  Note that if the parent is
           ;; a new task, the parent is assigned a tmp-ref that is stored in 
           ;; ToodledoID property of the parent entry.
           ((not (string= hash computed-hash))
            (let ((edit-task (org-toodledo-limit-fields task))
                  (id (org-toodledo-task-id task)))
              (when (org-toodledo-task-completed task)
                ;; XXXCJ - make sure completed is handled correctly:
                ;;   DONE state should set the CLOSED timestamp
                )
              
              (aput 'tasks-by-title-alist (org-toodledo-task-title task) edit-task)
              
              (cond
               ;; No parent, not a child task, just an edit task
               ((null parent-task)
                (aput 'edit-task "parent" "0")
                (setq edit-tasks (append edit-tasks (list edit-task)))
                )

               ;; Edit task, but parent already is synced and has an assigned Toodledo ID.
               (parent-id
                (aput 'edit-task "parent" parent-id)
                (setq edit-tasks (append edit-tasks (list edit-task)))
                )
               
               ;; Edit task, but parent is new
               (parent-ref
                ;; Save this task in edit-child-task-alist for easy lookup later
                (aput 'edit-child-tasks-alist id edit-task)
                
                ;; Track this child as waiting for this parent
                (aput 'new-parent-edit-child-alist
                      parent-ref (append (cdr (assoc parent-ref new-parent-edit-child-alist)) (list id)))
                )
               
               (t (error "Edit task has a parent, but parent task has neither a tmp-ref nor ID"))
               )
              )
            )

           ;; No action on this task, just save in alist for future reference
           (t
            (aput 'tasks-by-title-alist (org-toodledo-task-title task) task)
            )
           )
          )
        )
      
      ;; Issue a single call for new-tasks
      (while new-tasks
        (setq new-tasks-count (+ new-tasks-count (length new-tasks)))
        (let ((result (org-toodledo-server-add-tasks new-tasks)))

          ;; Reset new-tasks, a second round of new-tasks may be created
          ;; from new child tasks waiting on this parent
          (setq new-tasks nil)
          (dolist (m result)
            (let ((ref (cdr (assoc "ref" m)))
                  (id (cdr (assoc "id" m)))
                  (mod (cdr (assoc "modified" m)))
                  (parent-id (cdr (assoc "parent" m)))
                  )
              (if (and ref (not (string= ref ""))
                       (org-toodledo-goto-todo-entry ref))
                  (progn
                    (org-entry-put (point) "ToodledoID" id)
                    (org-entry-put (point) "Sync" (format "%d" (float-time)))
                    (org-entry-put (point) "Modified" mod)
                    (org-toodledo-compute-hash t)
                    (message "Successfully synced new task ID %s / ref %s" id ref)

                    ;; Look in new-parent-new-child-alist to see if any new child
                    ;; tasks are waiting for this parent's id
                    (dolist (child-tmp-ref (cdr (assoc ref new-parent-new-child-alist)))
                      (let ((child-task (cdr (assoc child-tmp-ref new-child-tasks-alist))))
                        (aput 'child-task "parent" id)
                        (setq new-tasks (append new-tasks (list child-task)))
                        (adelete 'new-parent-new-child-alist ref)
                        )
                      )
                    
                    ;; Look in new-parent-new-child-alist to see if any new child
                    ;; tasks are waiting for this parent's id
                    (dolist (child-id (cdr (assoc ref new-parent-edit-child-alist)))
                      (let ((child-task (cdr (assoc child-id edit-child-tasks-alist))))
                        (aput 'child-task "parent" id)
                        (setq edit-tasks (append edit-tasks (list child-task)))
                        (adelete 'new-parent-edit-child-alist ref)
                        )
                      )
                    )
                (message "Failed to update new task with reference %S with task ID %S" ref id)
                )
              )
            )
          
          (when new-parent-new-child-alist
            (error (format "Orphaned new child tasks never got a parent ID: %S" new-parent-new-child-alist)))

          (when new-parent-edit-child-alist
            (error (format "Orphaned edit child tasks never got a parent ID: %S" new-parent-edit-child-alist)))
          )
        )
      
      ;; Issue a single call for edit-tasks
      (when edit-tasks
        (let ((result (org-toodledo-server-edit-tasks edit-tasks)))
          (dolist (m result)
            (let ((id (cdr (assoc "id" m)))
                  (mod (cdr (assoc "modified" m))))
              (if (and id (not (string= id ""))
                       (org-toodledo-goto-todo-entry id nil))
                  (progn
                    (org-entry-put (point) "Sync" (format "%d" (float-time))) ;
                    (org-entry-put (point) "Modified" mod)
                    (org-toodledo-compute-hash t)
                    (message "Successfully edited task ID %s" id)
                    )
                (message "Failed to update edited task ID %S" id)))        
            )
          )
        )
      
      ;; Issue a single call for delete-tasks
      (when delete-tasks
        (let ((result (org-toodledo-server-delete-tasks delete-tasks)))
          (dolist (id result)
            (if (and id (not (string= id ""))
                     (org-toodledo-goto-todo-entry id nil))
                (progn
                  (org-back-to-heading t)
                  (delete-region
                   (point)
                   (if (and (end-of-line)
                            (re-search-forward org-complex-heading-regexp nil t))
                       (match-beginning 0)
                     (org-end-of-subtree t t)
                     (point)))
                  (message "Successfully deleted task ID %s" id)
                  )
              (message "Failed to delete task ID %S" id))
            )
          )
        )
      
      ;; Finally, update account info
      (unless skip-import
        (org-toodledo-goto-base-entry)

        ;; Refresh account-info, as it lastedit/lastdelete may have changed after
        ;; sending updates to the server
        (setq account-info (org-toodledo-get-account-info))
        (org-entry-put (point) "ToodledoLastSync" (format "%.0f" (float-time)))
        (org-entry-put (point) "ToodledoLastEdit" (cdr (assoc "lastedit_task" account-info)))
        (org-entry-put (point) "ToodledoLastDelete" (cdr (assoc "lastdelete_task" account-info))))
      
      (when columns-pos
        (goto-char columns-pos)
        (org-columns))

      (let* ((imod (length server-edit-tasks))
             (idel (length server-delete-tasks))
             (onew new-tasks-count)
             (omod (length edit-tasks))
             (odel (length delete-tasks))
             (tot (+ imod idel onew omod odel)))
        
        (if (= 0 tot)
            (message "Sync complete, no changes")
          (message (concat (format "Sync complete, %d changes: " tot)
                           (if (> (+ imod idel) 0) 
                               (concat "recv " 
                                       (if (> imod 0) (format "%d mod " imod))
                                       (if (> idel 0) (format "%d del " idel))
                                       (if (> (+ onew omod odel) 0) ", ")))
                           (if (> (+ onew omod odel) 0) 
                               (concat "sent " 
                                       (if (> onew 0) (format "%d new " onew))
                                       (if (> omod 0) (format "%d mod " omod))
                                       (if (> odel 0) (format "%d del " odel))))))
          (sleep-for org-toodledo-sync-message-time))
        (list tot imod idel onew omod odel))
      )
    )
  )

(defun org-toodledo-parse-current-task ()
  "Parse the org task at point and extract all toodledo related fields.  Retrun
an alist of the task fields."
  (save-excursion
    (org-back-to-heading t)
    (when (and (looking-at org-complex-heading-regexp)
               (match-string 2)) ;; the TODO keyword
      (let* (info
             (status (match-string-no-properties 2))
             (priority (match-string-no-properties 3))
             (title (match-string-no-properties 4))
             (tags (match-string-no-properties 5))
             (id (org-entry-get (point) "ToodledoID"))
             (deadline (org-entry-get nil "DEADLINE"))
             (scheduled (org-entry-get nil "SCHEDULED"))
             (closed (org-entry-get nil "CLOSED"))
             context)

        (if (and (string= status "DONE")
                 (null closed))
            (progn
              (org-add-planning-info 'closed (org-current-effective-time))
              (setq closed (org-entry-get nil "CLOSED"))))
        
        (when tags
          (setq tags
                (delq nil
                      (mapcar
                       (lambda (tag)
                         (if (> (length tag) 0)
                             (if (string-match (org-re "@\\([[:alnum:]_]+\\)") tag)
                                 (setq context (org-toodledo-context-to-id (match-string 1 tag)))
                               tag)))
                       (split-string tags ":")))))
        (setq info
              (list
               (cons "id" id)
               (cons "title" title)
               (cons "length" (org-entry-get (point) "Effort"))
               (cons "context" context) 
               (cons "tag" (mapconcat 'identity tags " "))
               (cons "completed" 
                     (if (equal status "DONE") 
                         (format "%.0f" (org-time-string-to-seconds closed)) "0"))
               (cons "modified" (org-entry-get (point) "Modified"))
               (cons "sync" (org-entry-get (point) "Sync"))
               (cons "status" (org-toodledo-map-status status))
               (cons "priority"
                     (cond
                      ((equal priority "[#A]") "3")
                      ((equal priority "[#B]") "2")
                      ((equal priority "[#C]") "1")
                      ((equal priority "[#D]") "0")
                      (t "2"))) ;; Force org-mode's no priority to be same as [#B] as is done in org-mode.
               (cons "note"
                     (org-toodledo-entry-note))))
        (when (org-entry-get nil "Folder")
          (aput 'info "folder" (org-toodledo-folder-to-id (org-entry-get nil "Folder"))))

        (when (org-entry-get nil "Goal")
          (aput 'info "goal" (org-toodledo-goal-to-id (org-entry-get nil "Goal"))))
        
        (when deadline
          ;;(aput 'info "duedate" (format "%.0f" (org-time-string-to-seconds deadline)))
          (aput 'info "duedate" (format "%.0f" 
                                        (+ (car (current-time-zone)) (org-time-string-to-seconds deadline))))
          (unless 
              (and
               (= 0 (caddr (org-parse-time-string deadline)))
               (= 0 (cadr (org-parse-time-string deadline))))
          (aput 'info "duetime" (format 
                                 "%.0f" (+ (car (current-time-zone)) (org-time-string-to-seconds deadline)))))
          (let ((repeat (org-toodledo-org-to-repeat deadline)))
            (when repeat
              (aput 'info "repeat" (car repeat))
              (aput 'info "repeatfrom" (cdr repeat))
              )
            )
          )
        (when scheduled
          (aput 'info "startdate" (format
                                   "%.0f" (+ (car (current-time-zone)) (org-time-string-to-seconds scheduled))))
          (unless 
              (and
               (= 0 (caddr (org-parse-time-string scheduled)))
               (= 0 (cadr (org-parse-time-string scheduled))))
            (aput 'info "starttime" (format "%.0f"
                                            (+ (car (current-time-zone)) (org-time-string-to-seconds scheduled))))))
        (aput 'info "parent" (org-toodledo-get-parent-id))
        info))))

(defun org-toodledo-get-parent-id ()
  "Return the ToodledoID of the immediate parent task.  Requires Pro account subscription"
  (save-excursion 
    (or (if (and (org-toodledo-pro) (org-up-heading-safe))
            (org-entry-get nil "ToodledoID")) 
        "0")))

(defun org-toodledo-process-task (task)
  "Process TASK definition, comparing with all currently defined tasks.
  - if TASK is not yet known (by id), create a new task
  - if TASK is known but local copy is not modified, update the local task
  - if TASK is known and local copy was modified, insert TASK as a duplicate"
  (save-excursion
    (if (org-toodledo-goto-todo-entry (org-toodledo-task-id task) t)

        ;; Found this entry already -- check local modified time vs server modified time
        (let* ((server-modified (org-toodledo-task-modified task))
               (local-modified (or (org-entry-get (point) "Modified") "0"))
               (local-lastsync (or (org-entry-get (point) "Sync") "0"))
               (hash (org-entry-get (point) "Hash"))
               (computed-hash (org-toodledo-compute-hash))
               (touched (or (not (string= hash computed-hash))
                            (> (string-to-number local-modified)
                               (string-to-number local-lastsync))))
               (level (elt (org-heading-components) 0))
               )
          (cond

           ;; Not touched locally, and server did modify it; delete and recreate
           ((and (not touched) 
                 (> (string-to-number server-modified) (string-to-number local-modified)))
            (org-toodledo-insert-new-task task t t)
            )
           
           ((and touched
                 (> (string-to-number server-modified) (string-to-number local-modified)))
            (message "Task %s was modified locally and on the server, both are saved" 
                     (org-toodledo-task-id task))
            (org-toodledo-insert-new-task task t)
            ;; XXXCJ - how to communicate this "duplicate" back to the user?
            ;;   - on sync, give user a number of "dups"?
            ;;   - add a property or a tag indicating its a dup?
            ;;   - on sync, check for dups and don't sync until the user resolves all dups
            ;;   - have a special check for dups function, lets user pick one or the other or edit
            )
           )
          )

      ;; Not found, add as new
      (if (and org-toodledo-sync-import-new-tasks
               (or org-toodledo-sync-new-completed-tasks
                   (not (org-toodledo-task-is-completed task)))
               (or (not org-toodledo-test-mode)
                   (string-match "ORGTOODLEDOTEST" (org-toodledo-task-title task))))
          
          (org-toodledo-insert-new-task task))
      )
    )
  )

;;
;; Contexts for inserting a task, and where to put it:
;;
;;   1) Brand new task pulled in from server
;;
;;      - if a parent task is known, put it as a child
;;        - level computed as parent+1
;;
;;      - if no parent, add to the end of the base-entry
;;
;;   2) Edit of an existing task, AT-POINT is non-nil and point is at
;;      the task to edit, REPLACE is non-nil
;;
;;      - parent task may be new, put it as a child, but don't move 
;;        it if the existing task was already a proper child
;;        - level computed as parent+1
;;
;;      - else, put it in the same place as the existing task
;;        - level should be taken from the old task
;; 
;;   3) Duplicate of an existing task, AT-POINT is non-nil and point
;;      is at the task to edit REPLACE is nil
;;
;;      - parent task may be new, put it as a child
;;        - level computed as parent+1
;;
;;      - else, put it in the same place as the existing task
;;        - level should be taken from the old task
;;
(defun org-toodledo-insert-new-task (task &optional at-point replace)
  (save-excursion
    
    (let* ((repeat (org-toodledo-repeat-to-org 
                    (org-toodledo-task-repeat task) (org-toodledo-task-repeatfrom task)))
           (taskid (org-toodledo-task-id task))
           (priority (org-toodledo-task-priority task))
           (context (org-toodledo-task-context task))
           (note (org-toodledo-task-note task))
           (duedate (org-toodledo-task-duedate task))
           (duetime (org-toodledo-task-duetime task))
           (startdate (org-toodledo-task-startdate task))
           (starttime (org-toodledo-task-starttime task))
           (modified (org-toodledo-task-modified task))
           (parent (org-toodledo-task-parent task))
           (folder (org-toodledo-task-folder task))
           (goal (org-toodledo-task-goal task))
           (length (org-toodledo-task-length task))
           (old-parent (if at-point (org-toodledo-get-parent-id)))
           (level (if at-point (elt (org-heading-components) 0)))
           pos
           )

      (when replace
        (delete-region (progn (org-back-to-heading t) (point))
                       (progn (goto-char (match-end 0))
                              (if (re-search-forward org-complex-heading-regexp nil t)
                                  (goto-char (match-beginning 0))
                                (org-end-of-subtree t t)))))
      
      (cond
       ;; Always put this task as a direct child if parent is present
       ((and parent (not (string= parent "0")))
        ;; ...but only move if the parent changed!
        (when (not (string= parent old-parent))
          (org-toodledo-goto-todo-entry parent)
          (setq level (1+ (elt (org-heading-components) 0)))
          (org-end-of-subtree t t)
          )
        )
       
       ((or 
         ;; Old parent set, new parent cleared
         (and old-parent (not (string= old-parent "0"))
              (or (null parent) (string= parent "0")))
         ;; or brand new task
         (not at-point))
        
        (org-toodledo-goto-base-entry)
        (setq level (1+ (elt (org-heading-components) 0)))
        (org-end-of-subtree t t)
        )
       )
    
      (insert (make-string (or level 2) ?*) " " )
      (setq pos (point-marker))
      (insert (concat
               (org-toodledo-task-status-to-org task) " "
               (cond
                ((equal priority "-1") "[#D] ") 
                ((equal priority "0")  "[#D] ")
                ((equal priority "1")  "[#C] ") 
                ((equal priority "2")  "[#B] ") 
                ((equal priority "3")  "[#A] "))
               (org-toodledo-task-title task)
               (if (and context (not (equal context "0")))
                   (concat " :@" (org-toodledo-id-to-context context) ":") 
                 "")
               "\n"))
      
      ;; note => becomes the task textual contents
      (if note
          (insert note "\n"))

      ;; duedate => "DEADLINE: <2011-08-21 Sun>" 
      ;; If a repeat string was found, it is added: "DEADLINE: <2011-08-21 Sun +1m>"
      (if (and duedate
               (not (<= (string-to-number duedate) 0)))    
          (if (and duetime
               (not (<= (string-to-number duetime) 0)))
              (setq duedate (concat org-deadline-string " "
                                    (org-toodledo-format-date duedate duetime repeat)))
            (setq duedate (concat org-deadline-string " "
                                  (org-toodledo-format-date duedate nil repeat))))
        (setq duedate nil))
      
      ;; startdate => "SCHEDULED: <2011-08-21 Sun>" 
      ;; If a repeat string was found, it is added: "DEADLINE: <2011-08-21 Sun +1m>"
      (if (and startdate
               (not (<= (string-to-number startdate) 0)))
          (if (and starttime
               (not (<= (string-to-number startdate) 0)))
              (setq startdate (concat (make-string (if duedate 1 (1+ (or level 2))) ? )
                                  org-scheduled-string " "
                                  (org-toodledo-format-date startdate starttime repeat)))
            (setq startdate (concat (make-string (if duedate 1 (1+ (or level 2))) ? )
                                  org-scheduled-string " "
                                  (org-toodledo-format-date startdate nil repeat))))
        (setq startdate nil))
      
      (when (or duedate startdate)
        (insert (make-string (1+ (or level 2)) ? ))
        (if duedate (insert duedate))
        (if (and duedate startdate) (insert " "))
        (if startdate (insert startdate))
        (insert "\n"))

      ;; create a properties drawer for all details
      (goto-char pos)
      (if taskid (org-entry-put (point) "ToodledoID" taskid))
      (if modified (org-entry-put (point) "Modified" modified))

      (if (and folder (not (equal folder "0")) (not (equal folder "")))
          (org-entry-put (point) "Folder" (org-toodledo-folder-to-id folder)))
      
      (if (and goal (not (equal goal "0")) (not (equal goal "")))
          (org-entry-put (point) "Goal" (org-toodledo-goal-to-id goal)))
      
      (org-entry-put (point) "Sync" (format "%d" (float-time (current-time))))
      
      (if length 
          (org-entry-put (point) "Effort" (org-toodledo-task-length task)))

      (org-toodledo-compute-hash t)
      )
    )
  )

(defun org-toodledo-delete-local-task (id)
  "Delete the task text for ID from the current buffer.  This
does no interaction with the server.  This is primarily used when
notified that a task on th server was deleted.

In most cases org-toodledo-mark-task-deleted is more appropriate."

  (if (and id (not (string= id ""))
           (org-toodledo-goto-todo-entry id t))
      (progn
        (org-back-to-heading t)
        (delete-region
         (point)
         (if (and (end-of-line)
                  (re-search-forward org-complex-heading-regexp nil t))
             (match-beginning 0)
           (org-end-of-subtree t t)
           (point)))
        )
    )
  )

(defun org-toodledo-mark-task-deleted ()
  "Marks the current task as deleted.  It will be deleted from the server
and from the local org file on the next sync"
  (interactive "")
  (save-excursion
    (let ((start-pos (point))
          (columns-pos (if (and (boundp 'org-columns-begin-marker) org-columns-begin-marker)
                           (marker-position org-columns-begin-marker) nil))
          )
      (when columns-pos
        (org-columns-quit))
      
      (org-back-to-heading t)
      (let ((task (org-toodledo-parse-current-task))
            response)
        (if (> (length (org-toodledo-task-id task)) 0)
            (org-entry-put (point) "Deleted" "1"))
        )
      
      (when columns-pos
        (goto-char columns-pos)
        (org-columns))
      
      (goto-char start-pos)
      )
    )
  )

;;
;; Field related functions
;;

;; Create a convenience function "org-toodled-task-<field>" for each field
;; of a task
(mapc (lambda (field)
        (eval `(defun ,(intern (concat "org-toodledo-task-" field)) (task)
                 ,(concat "Return the task property '" field "' for TASK")
                 (cdr (assoc ,field task)))))
      org-toodledo-fields)

(defun org-toodledo-limit-fields (task &optional fields)
  (unless fields
    (setq fields org-toodledo-fields-send))
  (let (new-task)
    (mapc (lambda (key) (let ((elem (assoc key task)))
                          (when elem (setq new-task (append (list elem) new-task))))) fields)
    new-task
    )
  )

(defun org-toodledo-entry-note ()
  "Extract the note for this task."
  (save-excursion
    (org-back-to-heading t)
    (when (looking-at org-complex-heading-regexp)
      (goto-char (match-end 0))
      (let ((text (buffer-substring-no-properties
                   (point)
                   (if (re-search-forward org-complex-heading-regexp nil t)
                       (match-beginning 0)
                     (org-end-of-subtree t t)))))
        (with-temp-buffer
          (insert text)

          ;; Pull out DEADLINE / SCHEDULED / CLOSED fields
          (dolist (str (list (regexp-quote org-deadline-string)
                             (regexp-quote org-scheduled-string)
                             (regexp-quote org-closed-string)))
            (goto-char (point-min))
            (when (re-search-forward
                   (concat "\\<" str " +[<\[][^]>\n]+[]>][ \t]*") nil t)
              (replace-match "")))

          ;; Drop any empty lines
          (goto-char (point-min))
          (while (re-search-forward "\n\n+" nil t)
            (replace-match "\n"))

          ;; org-export-remove-or-extract-drawers removed an argument sometime around version 7
          (if (>= (string-to-number org-version) 7)
              (org-export-remove-or-extract-drawers org-drawers nil)
            (org-export-remove-or-extract-drawers org-drawers nil nil))

          ;; Trim leading/trailing empty lines, but preserve whitepace at the beginning of the line
          (let ((s (buffer-substring-no-properties (point-min)
                                                   (point-max))))
            (if (string-match "\\(\\`[ \t]*[\n\r]+\\)+" s)  (setq s (replace-match "" t t s)))
            (if (string-match "\\([\n\r]+[ \t]*\\)+\\'" s) (setq s (replace-match "" t t s)))
            s)
          )
        )
      )
    )
  )

;;
;; Status related functions
;;

(defun org-toodledo-map-status (status &optional to-org)
  (cond 
   (to-org
    (if (string-match "^[0-9]+" status)
        (setq status (cdr (assoc status org-toodledo-api-status-map))))
    (cdr (assoc status org-toodledo-status-to-org-map)))
   
   ((string= status "DONE")
    "0")

   (t
    (car (rassoc 
          (car (rassoc status org-toodledo-status-to-org-map))
          org-toodledo-api-status-map)))
   )
  )

(defun org-toodledo-task-is-completed (task)
  (let ((comp (org-toodledo-task-completed task)))
    (not (or (null comp) (equal comp "") (equal comp "0")))))
     
(defun org-toodledo-task-status-to-org (task)
  (let ((comp (org-toodledo-task-completed task))
        (status (org-toodledo-task-status task)))
    (cond
     ((not (or (null comp) (equal comp "") (equal comp "0"))) "DONE")
     (t (org-toodledo-map-status status t))
     )))

;;
;; Repeat parsing and translation (ie. every 1 month)
;;

;; (assert (equal (org-toodledo-repeat-to-org nil) ""))
;; (assert (equal (org-toodledo-repeat-to-org "Every 1 week") "+1w"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 1 month") "+1m"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 1 year") "+1y"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 1 day") "+1d"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 2 weeks") "+2w"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 2 months") "+2m"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 6 months") "+6m"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 3 months") "+3m"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 3 months" 1) ".+3m"))
;; (assert (equal (org-toodledo-repeat-to-org "Every 1 week" 1) ".+1w"))

(defun org-toodledo-repeat-to-org (repeat &optional from)
  "Turn REPEAT string into org-mode style repeat sequence.  The second
argument FROM indicates if the repeat is from the due-date (0) or 
from the completion date (1). 

The format for REPEAT must be of the form \"Every X T\". Where X
is a number and T is a unit of time (day/week/month/year).

Examples: Every 3 days, Every 1 month, Every 2 years, Every 16 weeks.

Note the Toodlde 2.0 API supports 2 additional formats which are
not supported by this code: \"On the X D of each month\", and
\"Every W\".
"
  (if (not from) (setq from 0))
  (when (stringp from) (setq from (string-to-number from)))
  (cond
   ((null repeat) 
    "")
   ((string-match "Every \\([0-9]+\\) day" repeat)
    (concat (if (= from 0) "+" ".+") (match-string 1 repeat) "d"))
   ((string-match "Every \\([0-9]+\\) week" repeat)
    (concat (if (= from 0) "+" ".+")  (match-string 1 repeat) "w"))
   ((string-match "Every \\([0-9]+\\) month" repeat)
    (concat (if (= from 0) "+" ".+")  (match-string 1 repeat) "m"))
   ((string-match "Every \\([0-9]+\\) year" repeat)
    (concat (if (= from 0) "+" ".+") (match-string 1 repeat) "y"))
   (t 
    (message "Unsupported repeat string format: %s" repeat)
    "")
   )
  )

(defun org-toodledo-org-to-repeat (string)
  "Extract org-mode style repeat information from STRING and return
as a Toodledo style string.  Return nil if STRING has no repeat information"
  (if (string-match "\\(\\.?\\)\\+\\([0-9]+\\)\\([wmdy]\\)" string)
      (cons
       (format "Every %s %s" (match-string 2 string)
               (let ((interval (match-string 3 string)))
                 (cond ((string= interval "d") "day")
                       ((string= interval "w") "week")
                       ((string= interval "m") "month")
                       ((string= interval "y") "year"))))
       (format "%d" (length (match-string 1 string))))
    nil)
  )


;;
;; Date Handling
;;

;; (assert (equal (org-toodledo-format-date "2003-08-12") "<2003-08-12 Tue>"))

(defun org-toodledo-format-date (date &optional time repeat)
  "Return yyyy-mm-dd day for DATE."
  (concat
   "<"
   (format-time-string
    "%Y-%m-%d %a"
    (cond
     ((listp date) date)
     ((numberp date) (seconds-to-time date))
     ((and (stringp date)
           (string-match "^[0-9]+$" date))
      (seconds-to-time (string-to-number date)))
     (t (apply 'encode-time (org-parse-time-string date)))))
   (when time 
     (concat 
      " "  (format-time-string 
            "%H:%M" 
            (seconds-to-time 
             (+ (car (current-time-zone)) (string-to-number time))))))
   (when repeat (concat " " repeat) "")
   ">"))

;;
;; Finding TODO tasks
;;

(defun org-toodledo-find-todo-entry (id &optional noerror prop pos)
  "Find entry with property PROP equal to ID.  If PROP is not specified, defaults
to ToodledoID.  If POS is t, return position, otherwise a marker."
  (save-excursion 
    (goto-char (point-min))
    (unless prop (setq prop "ToodledoID"))
    (if (re-search-forward (concat "^[ \t]*:" prop ":[ \t]*" id) nil noerror)
        (progn (org-back-to-heading t)
               (if pos (point) (point-marker)))
      nil)))

(defun org-toodledo-goto-todo-entry (id &optional noerror prop)
  "Find and goto entry with property PROP equal to ID.  If PROP is not specified, defaults
to ToodledoID"
  (let ((pos (org-toodledo-find-todo-entry id noerror prop t)))
    (when pos
      (goto-char pos))))

(defun org-toodledo-find-base-entry (&optional noerror pos)
  "Find base entry with 'ToodledoLastSync' property.  If POS is t, 
return position, otherwise a marker."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^[ \t]*:ToodledoLastSync:" nil noerror)
        (progn 
          (org-back-to-heading t)
          (if pos (point) (point-marker)))
      nil)))

(defun org-toodledo-goto-base-entry (&optional noerror)
  "Find and goto base entry with 'ToodledoLastSync' property."
  (let ((pos (org-toodledo-find-base-entry t t)))
    (when pos (goto-char pos))))

;;
;; Hash Function
;;
(defun org-toodledo-compute-hash (&optional update task)
  "Compute an md5 hash of all user modifyable fields of the current task."
  (if (and task update)
      (error "Cannot update a task that was passed as an argument"))

  (unless task (setq task (org-toodledo-parse-current-task)))
  (let* ((text (mapconcat (lambda (field) (cdr (assoc field task))) org-toodledo-hash-fields ""))
         (hash (md5 text)))
    ;;(message "org-toodledo-compute-hash: %s from %s" hash text)
    (when update
      (org-entry-put (point) "Hash" hash))
    hash)
  )

;;
;; Save Hook
;;
(defun org-toodledo-save-hook ()
  "Save hook called before saving a file.  If this is an org-mode file and 
this file has been synced with Toodledo, check for saving.  

See org-toodledo-sync-on-save."  
  (when (and (eq major-mode 'org-mode)
             (org-toodledo-find-base-entry t))
    (save-excursion
      (let ((sync
             (cond 
              ((string= org-toodledo-sync-on-save "ask")
               (y-or-n-p "Sync with Toodledo? "))
              ((string= org-toodledo-sync-on-save "yes") t)
              (t nil))))
        (when sync
          (org-toodledo-sync))))))

(add-hook 'before-save-hook 'org-toodledo-save-hook)

;;
;; Miscellaneous
;;

(defun org-toodledo-server-add-tasks (tasks)
  "Add TASKS"
  (org-toodledo-server-addedit-tasks "tasks/add" tasks))

(defun org-toodledo-server-edit-tasks (tasks)
  "Edit TASKS"
  (org-toodledo-server-addedit-tasks "tasks/edit" tasks))

(defun org-toodledo-parse-tasks-xml (xmlresult)
  "Parse the XMLRESULT into a list of task alists of fields."
  (mapcar 
   (lambda (m)
     (mapcar (lambda (cell)
               (cons (symbol-name (car cell)) (caddr cell))) (cddr m)))
   (cddar xmlresult)
   )
  )

(defun org-toodledo-server-addedit-tasks (method tasks)
  "Add/edit TASKS, a list of alists of task fields to set.  This returns 
a list of alists of fields returned from the server."
  (org-toodledo-mapsublist 
   (lambda (partial-tasks)
     (let (params)
       (aput 'params "tasks" (json-encode-array partial-tasks))
       (aput 'params "fields" "parent")
       (org-toodledo-parse-tasks-xml (org-toodledo-call-method method params))))
   tasks 50)
  )
  
(defun org-toodledo-server-delete-tasks (taskids)
  "Delete TASKIDS, a list of task ids to delete.  Returns a list of results."
  (org-toodledo-mapsublist
   (lambda (partial-taskids)
     (let (params)
       (aput 'params "tasks" (json-encode-array partial-taskids))
       (mapcar 
        (lambda (m) (caddr m))
        (cddar (org-toodledo-call-method "tasks/delete" params))))
     )
   taskids 50)
  )


(defun org-toodledo-call-method (method-name &optional params dont-retry)
  "Call METHOD-NAME with PARAMS and return the parsed XML."

  (let (send-params)
    ;; Convert "unix" to 'unix
    (unless dont-retry
      (setq send-params (mapcar (lambda (e) 
                                  (let ((key (intern (car e)))
                                        (value (cdr e)))
                                    (when (listp value)
                                      (setq value (car value)))
                                    (cons key value))) params)))
    (aput 'send-params 'unix "1")
    (aput 'send-params 'key (org-toodledo-key))
    (aput 'send-params 'f "xml")
    
    (let* ((url (concat  (if org-toodledo-use-https "https" "http")
                         "://api.toodledo.com/2/" method-name ".php"))
           (response (http-post-simple url send-params))
           parsed-response)
      (org-toodledo-debug "Calling method: '%s'\n  params: %S" url send-params)
      (with-temp-buffer
        (insert (car response))
        (setq parsed-response (xml-parse-region (point-min) (point-max))))
      
      (org-toodledo-debug "Response:\n%S\nParsed Response:\n%S\n" response parsed-response)

      (when (eq 'error (caar parsed-response))
        (let ((msg (caddar parsed-response)))
          (if (and (string= msg "Invalid key") (not dont-retry))
              (progn 
                (message "Invalid key error from Toodledo.com, retrying")
                (setq org-toodledo-token nil)
                (setq parsed-response (org-toodledo-call-method method-name params t)))
            (error (format "Call to %s failed: %s" method-name (caddar parsed-response))))))
      parsed-response)))

(defmacro org-toodledo-make-lookup-function (name)
  "Create a lookup function and caching functions for NAME.

  variable:  org-toodledo-NAMEs
  functions: org-toodledo-get-NAMEs
             org-toodledo-NAME-to-id
             org-toodledo-id-to-NAME
"
  (let ((cache-var (concat "org-toodledo-" name "s"))
        (get-func (concat "org-toodledo-get-" name "s"))
        (add-method (concat name "s/add"))
        (get-method (concat name "s/get")))
    (list
     'progn
     `(defvar ,(intern cache-var) nil)
     `(defun ,(intern get-func) (&optional force)
        ,(concat "Store an alist of (title . id) in `" cache-var "'.
Reload if FORCE is non-nil.")
        (if (or force (null ,(intern cache-var)))
            (setq ,(intern cache-var)
                  (mapcar
                   (lambda (node)
                     (cons
                      (caddar (xml-get-children node 'name)) (caddar (xml-get-children node 'id))))
                   (xml-get-children (car
                                      (org-toodledo-call-method ,get-method)) (quote ,(intern name)))))
          ,(intern cache-var)))
     `(defun ,(intern (concat "org-toodledo-" name "-to-id")) (item) 
        "Return numeric ID for CONTEXT, creating if necessary."
        (let ((lookups ,(list (intern get-func))))
          (if (null (assoc item lookups))
              ;; Create it if it does not yet exist
              (let ((result
                     (org-toodledo-call-method
                      ,add-method
                      (list (cons "name" item)))))
                (if (eq (caar result) 'error)
                    (error (format "Failed to add new %s: %s" ,name item))
                  (setq ,(intern cache-var)
                        (cons (cons item
                                    (caddar (xml-get-children 
                                             (car (xml-get-children (car result) (quote ,(intern name))))
                                             'id)))
                              ,(intern cache-var))
                        lookups ,(intern cache-var)))))
          (cdr (assoc item lookups))))
     `(defun ,(intern (concat "org-toodledo-id-to-" name)) (id) 
        "Return name for context by ID."
        (let ((lookups ,(list (intern get-func))))
          (if (null (rassoc id lookups))
              nil
            (car (rassoc id lookups))))
        )
     )
    )
  )

(org-toodledo-make-lookup-function "context")
(org-toodledo-make-lookup-function "folder")
(org-toodledo-make-lookup-function "goal")

(defun org-toodledo-convert-xml-result-to-alist (info)
  "Convert INFO to an alist."
  (delq nil
        (mapcar
         (lambda (item)
           (if (listp item)
               (let ((key (symbol-name (car item)))
                     (value (elt item 2)))
                 (cons key (if value (decode-coding-string value 'utf-8))))))
         (xml-node-children (delete "\n\t" info)))))

(defun org-toodledo-refile-current-task (marker)
  (let (level)
    (org-cut-subtree)
    (goto-char marker)
    (setq level (org-get-valid-level (funcall outline-level) 1))
    (or (save-excursion (org-get-next-sibling))
        (org-end-of-subtree t t)
        (point-max))
    (org-paste-subtree level)
    )
  )

(defun org-toodledo-refile-current-task-to-heading (heading)
  (let ((marker (org-find-exact-headline-in-buffer heading)))
    (if marker
        (org-toodledo-refile-current-task marker)
      (error (format "No such heading %s" heading)))))

(defun org-toodledo-refile-current-task-to-id (id)
  (let ((marker (org-toodledo-find-todo-entry id)))
    (if marker
        (org-toodledo-refile-current-task marker)
      (error (format "No such task %s" id)))))

(defun org-toodledo-sublist (list from &optional to)
  "Return a sublist of LIST, from FROM to TO.
If END is omitted, it defaults to the length of the sequence.
Counting starts at 0. Like `subseq' and `substring' but solely for
lists."
  ;; Taken from http://osdir.com/ml/help-gnu-emacs-gnu/2009-11/msg00484.html
  (let ((start (nthcdr from list))) ;start reference
    (if to (butlast start
                    (- (+ from (length start)) ;if extract list at the end this makes it much faster
                       to))
      start)))

(defun org-toodledo-mapsublist (function list step)
  (let ((len (length list))
        result)
    (do ((offset 0 (+ step offset))) ((> offset len) nil)
      (let ((pr (funcall function (org-toodledo-sublist list offset (+ offset step)))))
        (setq result (append result pr))))
    result
    )
  )

(defun org-toodledo-run-tests ()
  "Run org-toodledo-test suite"
  (interactive)
  (require 'org-toodledo-test)
  (org-toodledo-test)
)

(defun org-toodledo-debug (str &rest args)
  (when org-toodledo-debug
    (save-excursion
      (set-buffer (get-buffer-create "*Org-toodledo-debug*"))
      (end-of-buffer)
      (insert (concat (apply 'format (append (list str) args)) "\n")))))

(provide 'org-toodledo)
