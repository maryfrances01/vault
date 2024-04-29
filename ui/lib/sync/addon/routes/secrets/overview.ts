/**
 * Copyright (c) HashiCorp, Inc.
 * SPDX-License-Identifier: BUSL-1.1
 */

import Route from '@ember/routing/route';
import { service } from '@ember/service';
import { hash } from 'rsvp';

import type FlagsService from 'vault/services/flags';
import type StoreService from 'vault/services/store';
import type VersionService from 'vault/services/version';

export default class SyncSecretsOverviewRoute extends Route {
  @service declare readonly store: StoreService;
  @service declare readonly flags: FlagsService;
  @service declare readonly version: VersionService;

  async model() {
    const isActivated = this.flags.secretsSyncIsActivated;
    const licenseHasSecretsSync = this.version.hasSecretsSync;
    const isManaged = this.flags.isManaged;

    return hash({
      licenseHasSecretsSync,
      isActivated,
      isManaged,
      destinations: isActivated ? this.store.query('sync/destination', {}).catch(() => []) : [],
      associations: isActivated
        ? this.store
            .adapterFor('sync/association')
            .queryAll()
            .catch(() => [])
        : [],
    });
  }
}
