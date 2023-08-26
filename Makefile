install: /usr/local/opnsense/service/conf/actions.d/actions_testnet.conf ${HOME}/testnet.sh

/usr/local/opnsense/service/conf/actions.d/actions_testnet.conf:
	install -v -m755 actions_testnet.conf /usr/local/opnsense/service/conf/actions.d/actions_testnet.conf

${HOME}/testnet.sh:
	install -v -m755 testnet.sh ${HOME}/testnet.sh
