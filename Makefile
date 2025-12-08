# Makefile for Azure Policy with Bicep
.PHONY: whatif whatif-debug deploy build lint decompile test clean prep

prep:
	mkdir -p ./compiled
	./scripts/prep-params.sh

build: clean lint prep
	mkdir -p ./compiled
	bicep build ./bicep/main.bicep --outdir ./compiled

lint:
	bicep lint ./bicep/main.bicep

decompile:
	mkdir -p ./decompiled
	bicep decompile ./compiled/main.json --outdir ./decompiled

test: clean
	./scripts/test-build.sh

whatif: build
	az deployment mg what-if --name "deployment001" --location "westeurope" --management-group-id "mg-corp" --template-file ./bicep/main.bicep --parameters @./bicep/main.parameters.json --no-pretty-print

whatif-debug: build
	az deployment mg what-if --name "deployment001" --location "westeurope" --management-group-id "mg-corp" --template-file ./compiled/main.json --parameters @./bicep/main.parameters.json --no-pretty-print --debug

deploy: build
	az deployment mg create --name "deployment001" --location "westeurope" --management-group-id "mg-corp" --template-file ./compiled/main.json --parameters @./bicep/main.parameters.json

clean:
	rm -rf compiled decompiled outputs