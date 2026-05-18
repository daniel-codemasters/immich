// ----------- daniel -------------
// Tests for the fork-only DeviceLabelsEditor admin component (storage template
// `{{device}}` -> friendly folder name map).
// ---------------------------------
import type { StorageTemplateDeviceDto } from '@immich/sdk';
import { screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { sdkMock } from '$lib/__mocks__/sdk.mock';
import DeviceLabelsEditor from '$lib/components/admin-settings/DeviceLabelsEditor.svelte';
import { renderWithTooltips } from '$tests/helpers';

const device = (deviceId: string, overrides: Partial<StorageTemplateDeviceDto> = {}): StorageTemplateDeviceDto => ({
  deviceId,
  assetCount: 5,
  lastUploadAt: '2026-05-01T12:00:00.000Z',
  ...overrides,
});

describe('DeviceLabelsEditor component', () => {
  beforeEach(() => {
    sdkMock.getStorageTemplateDevices.mockReset();
  });

  it('loads server-discovered devices on mount', async () => {
    sdkMock.getStorageTemplateDevices.mockResolvedValue([device('phone-abc')]);

    renderWithTooltips(DeviceLabelsEditor, { deviceLabels: {} });

    expect(await screen.findByText('phone-abc')).toBeInTheDocument();
    expect(sdkMock.getStorageTemplateDevices).toHaveBeenCalledTimes(1);
  });

  it('shows the empty state when there are no devices and no labels', async () => {
    sdkMock.getStorageTemplateDevices.mockResolvedValue([]);

    renderWithTooltips(DeviceLabelsEditor, { deviceLabels: {} });

    expect(await screen.findByText('admin.storage_template_device_no_devices')).toBeInTheDocument();
  });

  it('lists map entries that the server did not return', async () => {
    sdkMock.getStorageTemplateDevices.mockResolvedValue([]);

    renderWithTooltips(DeviceLabelsEditor, { deviceLabels: { 'manual-device': 'Daniel' } });

    expect(await screen.findByText('manual-device')).toBeInTheDocument();
    const label = screen.getByPlaceholderText('admin.storage_template_device_label_placeholder') as HTMLInputElement;
    expect(label.value).toBe('Daniel');
  });

  it('adds a trimmed device id to the labels map', async () => {
    const user = userEvent.setup();
    sdkMock.getStorageTemplateDevices.mockResolvedValue([]);
    const deviceLabels: Record<string, string> = {};

    renderWithTooltips(DeviceLabelsEditor, { deviceLabels });
    await screen.findByText('admin.storage_template_device_no_devices');

    const newId = screen.getByPlaceholderText('admin.storage_template_device_id_placeholder') as HTMLInputElement;
    await user.type(newId, '  new-phone  ');
    await user.click(screen.getByRole('button', { name: 'add' }));

    expect(deviceLabels).toEqual({ 'new-phone': '' });
    expect(newId.value).toBe('');
  });

  it('removes a device from the labels map when its trash button is clicked', async () => {
    const user = userEvent.setup();
    sdkMock.getStorageTemplateDevices.mockResolvedValue([]);
    const deviceLabels: Record<string, string> = { 'manual-device': 'Daniel' };

    renderWithTooltips(DeviceLabelsEditor, { deviceLabels });
    await screen.findByText('manual-device');

    await user.click(screen.getByRole('button', { name: 'remove' }));

    expect(deviceLabels).toEqual({});
  });

  it('disables the row controls when the disabled prop is set', async () => {
    sdkMock.getStorageTemplateDevices.mockResolvedValue([device('phone-abc')]);

    renderWithTooltips(DeviceLabelsEditor, { deviceLabels: { 'phone-abc': 'Daniel' }, disabled: true });
    await screen.findByText('phone-abc');

    expect(screen.getByPlaceholderText('admin.storage_template_device_label_placeholder')).toBeDisabled();
    expect(screen.getByRole('button', { name: 'remove' })).toBeDisabled();
  });
});
