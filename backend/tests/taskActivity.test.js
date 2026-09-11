import { describe, it, expect } from 'vitest';
import { taskManagementService } from '../src/services/taskManagementService.js';

describe('TaskManagementService._resolveActivityForArea', () => {
  it('returns null when no activity is configured', () => {
    const result = taskManagementService._resolveActivityForArea('area1', { areaType: 'Cleaning' }, {});
    expect(result).toBeNull();
  });

  it('uses global activityType as fallback with title-cased label', () => {
    const result = taskManagementService._resolveActivityForArea('area1', {}, {
      activityType: 'garbage_collection',
      taskTypeId: 'tt-1',
      taskTypeName: 'garbage_collection',
    });
    expect(result).toEqual({
      id: 'tt-1',
      name: 'garbage_collection',
      label: 'Garbage Collection',
    });
  });

  it('prefers per-area activity over global activityType', () => {
    const result = taskManagementService._resolveActivityForArea('area1', {}, {
      activityType: 'sweeping',
      areaActivities: {
        area1: { uid: 'tt-2', name: 'mopping', label: 'Mopping' },
      },
    });
    expect(result).toEqual({ id: 'tt-2', name: 'mopping', label: 'Mopping' });
  });

  it('supports string per-area activity', () => {
    const result = taskManagementService._resolveActivityForArea('areaX', { areaType: 'Cleaning' }, {
      areaActivities: { areaX: 'toilet_cleaning' },
    });
    expect(result.label).toBe('Toilet Cleaning');
    expect(result.name).toBe('toilet_cleaning');
  });

  it('falls back to areaType when only label is provided', () => {
    const result = taskManagementService._resolveActivityForArea('area1', { areaType: 'Washing' }, {
      areaActivities: { area1: { name: 'washing' } },
    });
    expect(result.label).toBe('Washing');
  });
});

describe('TaskManagementService._resolveActivitiesForArea', () => {
  it('returns [] when no activity is configured', () => {
    const result = taskManagementService._resolveActivitiesForArea('area1', { areaType: 'Cleaning' }, {});
    expect(result).toEqual([]);
  });

  it('returns single activity wrapped in array for global activityType', () => {
    const result = taskManagementService._resolveActivitiesForArea('area1', {}, {
      activityType: 'garbage_collection',
      taskTypeId: 'tt-1',
      taskTypeName: 'garbage_collection',
    });
    expect(result).toEqual([
      { id: 'tt-1', name: 'garbage_collection', label: 'Garbage Collection' },
    ]);
  });

  it('returns multiple activities when per-area value is an array', () => {
    const result = taskManagementService._resolveActivitiesForArea('area1', {}, {
      activityType: 'sweeping',
      areaActivities: {
        area1: [
          { uid: 'tt-2', name: 'mopping', label: 'Mopping' },
          { uid: 'tt-3', name: 'garbage_collection', label: 'Garbage Collection' },
        ],
      },
    });
    expect(result).toEqual([
      { id: 'tt-2', name: 'mopping', label: 'Mopping' },
      { id: 'tt-3', name: 'garbage_collection', label: 'Garbage Collection' },
    ]);
  });

  it('drops invalid entries from activity arrays', () => {
    const result = taskManagementService._resolveActivitiesForArea('area1', {}, {
      areaActivities: {
        area1: [
          { uid: 'tt-2', name: 'mopping', label: 'Mopping' },
          { foo: 'bar' },
        ],
      },
    });
    expect(result).toEqual([
      { id: 'tt-2', name: 'mopping', label: 'Mopping' },
    ]);
  });
});
