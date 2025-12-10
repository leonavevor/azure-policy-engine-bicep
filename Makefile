# Makefile for Azure Policy with Bicep
.PHONY: whatif deploy build lint decompile test clean prep

default: | help usage

# ARGs and ENV variables: (can be overridden via environment variables or command line arguments: eg: make deploy mg='my-mg' loc='eastus')
deploymentName ?= "deployment001"  # Set your deployment name here
mg ?= mg-root  # Set your management group ID here
loc ?= westeurope  # Set your deployment location here
templateFile ?= ./bicep/main.bicep  # Path to the main Bicep file
parametersFile ?= ./bicep/main.parameters.json  # Path to the main parameters file
debugEnabledArg ?= --debug
otherArgs ?=  # Placeholder for any additional arguments (whatever you wish to add)


help:
	@echo "Makefile for Azure Policy with Bicep"
	@echo ""
	@echo "Available targets:"
	@echo "  prep               Prepare the environment (create compiled directory and prepare parameters)"
	@echo "  build             Build the Bicep template"
	@echo "  lint              Lint the Bicep template"
	@echo "  decompile        Decompile the compiled ARM template back to Bicep"
	@echo "  test              Run test build script"
	@echo "  whatif           Perform a what-if deployment at management group level"
	@echo "  deploy           Deploy the Bicep template at management group level"
	@echo "  clean            Clean up compiled, decompiled, and outputs directories"
	@echo ""
	@echo "You can override default variables by passing them as arguments. For example:"
	@echo "  make deploy mg='my-mg' loc='eastus'"

usage:
	@echo "Usage: make [target] [VARIABLE=value ...]"
	@echo "Available targets: prep, build, lint, decompile, test, whatif, whatif-debug, deploy, clean"
	@echo "Example1: make deploy mg='my-mg' loc='eastus'"
	@echo "Example2: make build templateFile='./bicep/other.bicep' parametersFile='./bicep/other.parameters.json'"
	@echo "Example3: make whatif otherArgs='--no-color'"
	@echo "Example4 (overridden debugEnabledArg): make whatif debugEnabledArg=''"

prep:
	mkdir -p ./compiled
	./scripts/prep-params.sh --policy-dir ./policies --file-extension .json #--force-defaults --defaults-env ./.default.envs

build: clean lint prep
	mkdir -p ./compiled
	bicep build ${templateFile} --outdir ./compiled ${otherArgs}

lint:
	bicep lint ${templateFile} ${otherArgs}

decompile:
	mkdir -p ./decompiled
	bicep decompile ./compiled/main.json --outdir ./decompiled

test: clean
	./scripts/test-build.sh

whatif: build
	az deployment mg what-if --name ${deploymentName} --location ${loc} --management-group-id ${mg} --template-file ${templateFile} --parameters @${parametersFile} --no-pretty-print ${debugEnabledArg} ${otherArgs}

deploy: build
	az deployment mg create --name ${deploymentName} --location ${loc} --management-group-id ${mg} --template-file ${templateFile} --parameters @${parametersFile} ${debugEnabledArg} ${otherArgs}

whatif-mg: build
	az deployment mg what-if --name ${deploymentName} --location ${loc} --management-group-id ${mg} --template-file ./bicep/mg.bicep --no-pretty-print ${debugEnabledArg} ${otherArgs}

deploy-mg: build
	az deployment mg create --name ${deploymentName} --location ${loc} --management-group-id ${mg} --template-file ./bicep/mg.bicep ${debugEnabledArg} ${otherArgs}

clean:
	rm -rf compiled decompiled outputs