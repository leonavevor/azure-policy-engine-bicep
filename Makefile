# Makefile for Azure Policy with Bicep
.PHONY: whatif whatif-debug deploy build lint decompile test clean prep

# ARGs and ENV variables: (can be overridden via environment variables or command line arguments: eg: make deploy mg='my-mg' loc='eastus')
mg ?= "mg-root"  # Set your management group ID here
loc ?= westeurope  # Set your deployment location here
templateFile ?= ./bicep/main.bicep  # Path to the main Bicep file
parametersFile ?= ./bicep/main.parameters.json  # Path to the main parameters file

prep:
	mkdir -p ./compiled
	./scripts/prep-params.sh --policy-dir ./policies --file-extension .json --force-defaults --defaults-env ./.default.envs

build: clean lint prep
	mkdir -p ./compiled
	bicep build ${templateFile} --outdir ./compiled

lint:
	bicep lint ${templateFile}

decompile:
	mkdir -p ./decompiled
	bicep decompile ./compiled/main.json --outdir ./decompiled

test: clean
	./scripts/test-build.sh

whatif: build
	az deployment mg what-if --name "deployment001" --location ${loc} --management-group-id ${mg} --template-file ${templateFile} --parameters @${parametersFile} --no-pretty-print

whatif-debug: build
	az deployment mg what-if --name "deployment001" --location ${loc} --management-group-id ${mg} --template-file ${templateFile} --parameters @${parametersFile} --no-pretty-print --debug

deploy: build
	echo az deployment mg create --name "deployment001" --location ${loc} --management-group-id ${mg} --template-file ${templateFile} --parameters @${parametersFile}

whatif-mg: build
	#az deployment tenant what-if --name "deployment001" --location ${loc} --management-group-id ${mg} --template-file ./bicep/mg.bicep --parameters @${parametersFile} --no-pretty-print
	az deployment mg what-if --name "deployment001" --location ${loc} --management-group-id ${mg} --template-file ./bicep/mg.bicep --no-pretty-print

deploy-mg: build
	az deployment mg create --name "deployment001" --location ${loc} --management-group-id ${mg} --template-file ./bicep/mg.bicep

clean:
	rm -rf compiled decompiled outputs