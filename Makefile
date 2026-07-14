
cat-config:
	@base64 -D -i ~/.cora-cowork-config-dev/cora-cowork-config.txt | python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))' | pbcopy
