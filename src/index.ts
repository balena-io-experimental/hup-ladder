import * as balenaSdk from 'balena-sdk';

// balenaSdk.setSharedOptions({
// 	apiUrl: 'https://api.balena-staging.com/',
// })

const balena = balenaSdk();
// TODO: better way to source these? flags?
const UUID = ((process.env.UUID as unknown) as string) || undefined;
const TOKEN = ((process.env.TOKEN as unknown) as string) || undefined;
const RANDOM = ((process.env.RANDOM_ORDER as unknown) as boolean) || false;
const maxFails = ((process.env.MAX_FAILS as unknown) as number) || 10;

if (!UUID) {
	console.error('UUID required in environment');
	process.exit(1);
}

if (!TOKEN) {
	console.error('TOKEN required in environment');
	process.exit(1);
}

balena.auth.loginWithToken(TOKEN).then(() => {
	balena.auth.isLoggedIn().then((isLoggedIn: boolean) => {
		if (!isLoggedIn) {
			throw new Error('Authentication Error');
		}
	});
});

interface Device {
	deviceType: string;
	osVersion: string;
	osVariant: string;
}

enum HUPStatus {
	IDLE = 'idle',
	IN_PROGRESS = 'in_progress',
	DONE = 'done',
	ERROR = 'error',
}

const getDeviceData = async (uuid: string): Promise<Device> => {
	return await balena.models.device.get(UUID).then((device) => {
		return {
			deviceType: device.device_type,
			osVersion: device.os_version,
			osVariant: device.os_variant,
		};
	});
};

const getNextTargetVersion = async (
	deviceType: Device['deviceType'],
	osVersion: Device['osVersion'],
): Promise<string> => {
	return await balena.models.os
		.getSupportedOsUpdateVersions(deviceType, osVersion)
		.then((versions) => {
			if (versions.versions.length > 1) {
				return RANDOM
					? versions.versions[
							Math.floor(Math.random() * versions.versions.length)
					  ]
					: versions.versions[versions.versions.length - 2];
			} else {
				console.log('HUP ladder completed');
				process.exit(0);
			}
		});
};

const watchHUP = async (uuid: string, targetOS): Promise<boolean> => {
	const hupStatus = await balena.models.device.getOsUpdateStatus(UUID);
	console.log(`HUP status: ${hupStatus.status}`);
	if (hupStatus.status === HUPStatus.ERROR || hupStatus.fatal) {
		console.log(hupStatus.error);
		return false;
	} else if (hupStatus.status === HUPStatus.DONE) {
		const { deviceType, osVersion, osVariant } = await getDeviceData(UUID);
		if (osVersion !== targetOS) {
			console.log('HUP done but not completed');
			return false;
		}
		return true;
	}
};

const main = async () => {
	// send the hup
	// 	wait for the hup to finish
	// 	wait for device to update
	// 	if the HUP errors, bail (or maybe just retry?)
	// 	if the target isn't reached, bail
	// get the device
	let fails = 0;
	while (fails <= maxFails) {
		const { deviceType, osVersion, osVariant } = await getDeviceData(UUID);
		const targetOS = await getNextTargetVersion(deviceType, osVersion);
		console.log(`Updating ${UUID} to ${targetOS}..`);
		balena.models.device.startOsUpdate(UUID, targetOS);
		console.log(`Giving it a minute..`);
		if (!(await watchHUP(UUID, targetOS))) {
			console.log('HUP failed, retrying..');
			fails++;
		}
	}
	console.log(`HUP ladder exceeded error budget of ${maxFails}`);
	process.exit(1);
};

console.log('starting main');
main();
