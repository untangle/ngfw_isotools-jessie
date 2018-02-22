CWD := $(shell dirname $(shell readlink -f MAKEFILE_LIST))
NAME := $(shell basename $(shell readlink -f $(CWD)))

PKGTOOLS_DIR := $(CWD)/../../ngfw_pkgtools

## overridables
# repository
REPOSITORY ?= jessie
# distribution to draw packages from
DISTRIBUTION ?= current
# flavor
FLAVOR ?= untangle

# constants
ARCH := $(shell dpkg-architecture -qDEB_BUILD_ARCH)
TS := $(shell date +"%Y-%m-%dT%H%M%S")
HOST := $(shell hostname -s)
VERSION := $(shell cat $(PKGTOOLS_DIR)/resources/VERSION)
TMP_DIR := $(CWD)/tmp-$(FLAVOR)
AMI_LOG := $(TMP_DIR)/ami.log
TMP_IMAGE := $(TMP_DIR)/ami.raw
NETBOOT_HOST := netboot-server.untangle.int
IMAGES_DIR := /data/untangle-images-$(REPOSITORY)
# FIXME: find device dynamically, and then derive its ID
EBS_DEVICE := /dev/xvdf
EBS_ID := vol-06da60b13f650af2a
FULL_NAME := untangle-$(VERSION)_$(REPOSITORY)_$(ARCH)_current_$(TS)_$(HOST)_$(NAME).ami.txt

.PHONY: all clean image push

all: image

clean:
	rm -fr $(TMP_DIR)

$(TMP_DIR):
	mkdir -p $(TMP_DIR)

aws-image: $(TMP_DIR)
	fai-diskimage --cspace $(CWD) --hostname untangle-image --size 3G --class DEBIAN,JESSIE,BACKPORTS,GRUB_PC,CLOUD,EC2,UNTANGLE $(TMP_IMAGE)
	dd if=$(TMP_IMAGE) of=$(EBS_DEVICE) bs=300M
	bash volume-to-ami.sh -r $(REPOSITORY)-$(VERSION) $(EBS_ID) | tee $(AMI_LOG)

aws-push:
	awk '/"ImageId":/ { gsub(/"/,"",$$2); print $$2 }' $(AMI_LOG) | ssh $(NETBOOT_HOST) "cat > $(IMAGES_DIR)/$(VERSION)/$(FULL_NAME)"
