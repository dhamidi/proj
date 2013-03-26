README.org:
	@git checkout master -- README.org

README.html: README.org
	@emacsclient -t -a '' --eval "(and (find-file \"README.org\")(org-html-export-to-html)(delete-frame))"

index.html: README.html
	cp README.html index.html

.PHONY:
sync: index.html
	@( git status --porcelain | grep 'M README.org' ) && git add README.* && git commit -m 'sync with master' || echo 'nothing to sync'
