README.org:
	@git checkout master -- README.org

README.html: README.org
	@emacsclient -t -a '' --eval "(and (find-file \"README.org\")(org-html-export-to-html)(delete-frame))"

.PHONY:
sync: README.html
	@( git status --porcelain | grep 'M README.org' ) && git add README.* && git commit -m 'sync with master'
