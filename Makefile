PORTFILE_LANGUAGE_URL := https://raw.githubusercontent.com/judaew/tree-sitter-portfile/main/extra/portfile-language.json

.PHONY: update

update:
	curl --fail --silent --show-error --location \
		--output portfile-language.json \
		$(PORTFILE_LANGUAGE_URL)
