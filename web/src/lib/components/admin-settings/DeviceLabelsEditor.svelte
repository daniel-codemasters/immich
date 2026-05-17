<!--
  ----------- daniel -------------
  Fork-only component. Lets an admin map each upload device ID to a friendly
  folder name, consumed by the storage template `{{device}}` variable.
  ---------------------------------
-->
<script lang="ts">
  import { locale } from '$lib/stores/preferences.store';
  import { handleError } from '$lib/utils/handle-error';
  import { getStorageTemplateDevices, type StorageTemplateDeviceDto } from '@immich/sdk';
  import { Button, Card, CardBody, CardHeader, Code, IconButton, Input, LoadingSpinner, Text } from '@immich/ui';
  import { mdiTrashCanOutline } from '@mdi/js';
  import { DateTime } from 'luxon';
  import { t } from 'svelte-i18n';

  interface Props {
    deviceLabels: Record<string, string>;
    disabled?: boolean;
  }

  let { deviceLabels = $bindable(), disabled = false }: Props = $props();

  let devices: StorageTemplateDeviceDto[] = $state([]);
  let newDeviceId = $state('');

  // Union of devices discovered server-side and IDs already present in the map,
  // so manually added or currently-asset-less devices remain editable.
  let rows = $derived.by(() => {
    const ids = devices.map((device) => device.deviceId);
    for (const id of Object.keys(deviceLabels)) {
      if (!ids.includes(id)) {
        ids.push(id);
      }
    }
    return ids.map((deviceId) => ({
      deviceId,
      info: devices.find((device) => device.deviceId === deviceId),
    }));
  });

  const loadDevices = async () => {
    try {
      devices = await getStorageTemplateDevices();
    } catch (error) {
      handleError(error, $t('admin.storage_template_device_load_failed'));
    }
  };

  const formatDate = (iso: string) => DateTime.fromISO(iso).toLocaleString(DateTime.DATETIME_MED, { locale: $locale });

  const addDevice = () => {
    const id = newDeviceId.trim();
    if (id && deviceLabels[id] === undefined) {
      deviceLabels[id] = '';
    }
    newDeviceId = '';
  };

  const removeDevice = (deviceId: string) => {
    delete deviceLabels[deviceId];
  };
</script>

<Text size="small">{$t('admin.storage_template_device_labels')}</Text>

<Card class="mt-2 bg-light-50 text-sm shadow-none">
  <CardHeader>
    <Text>{$t('admin.storage_template_device_labels_description')}</Text>
  </CardHeader>
  <CardBody>
    {#await loadDevices()}
      <LoadingSpinner />
    {:then}
      {#if rows.length === 0}
        <Text color="secondary">{$t('admin.storage_template_device_no_devices')}</Text>
      {:else}
        <div class="flex flex-col gap-3">
          {#each rows as row (row.deviceId)}
            <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:gap-3">
              <div class="flex min-w-0 flex-1 flex-col gap-1">
                <Code class="truncate">{row.deviceId}</Code>
                {#if row.info}
                  <Text size="tiny" color="secondary">
                    {$t('admin.storage_template_device_summary', {
                      values: { count: row.info.assetCount, date: formatDate(row.info.lastUploadAt) },
                    })}
                  </Text>
                {/if}
              </div>
              <!--
                Input's outer wrapper is hard-coded `w-full` and the `class` prop only
                reaches its inner box, so sizing must be done on a wrapper div here —
                otherwise the Input's 100% basis starves the flex-1 device id column to 0.
              -->
              <div class="w-full shrink-0 sm:w-64">
                <Input
                  bind:value={deviceLabels[row.deviceId]}
                  placeholder={$t('admin.storage_template_device_label_placeholder')}
                  {disabled}
                />
              </div>
              <IconButton
                icon={mdiTrashCanOutline}
                aria-label={$t('remove')}
                size="medium"
                color="secondary"
                variant="ghost"
                {disabled}
                onclick={() => removeDevice(row.deviceId)}
              />
            </div>
          {/each}
        </div>
      {/if}

      <div class="mt-4 flex gap-2">
        <Input bind:value={newDeviceId} placeholder={$t('admin.storage_template_device_id_placeholder')} {disabled} />
        <Button size="small" onclick={addDevice} disabled={disabled || !newDeviceId.trim()}>{$t('add')}</Button>
      </div>
    {/await}
  </CardBody>
</Card>
