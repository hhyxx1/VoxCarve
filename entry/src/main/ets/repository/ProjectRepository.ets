import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import type { MediaProject } from '../domain/MediaModels';
import { EditGraph, EditHistorySnapshot } from '../domain/EditGraph';

export interface ProjectRepository {
  list(): Promise<MediaProject[]>;
  create(name: string): Promise<MediaProject>;
  loadEdits(projectId: number): Promise<EditGraph | undefined>;
  saveEdits(projectId: number, graph: EditGraph): Promise<void>;
}

const SCHEMA_VERSION = 2;
const CREATE_PROJECTS = 'CREATE TABLE IF NOT EXISTS projects (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, ' +
  'created_at_ms INTEGER NOT NULL, updated_at_ms INTEGER NOT NULL)';

export class LocalProjectRepository implements ProjectRepository {
  private context: common.UIAbilityContext;
  private opening?: Promise<relationalStore.RdbStore>;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private open(): Promise<relationalStore.RdbStore> {
    if (!this.opening) {
      this.opening = this.initialize().catch((error: BusinessError): relationalStore.RdbStore => {
        this.opening = undefined;
        throw new Error('PROJECT_STORE_UNAVAILABLE: ' + (error.code ?? error.message));
      });
    }
    return this.opening;
  }

  private async initialize(): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(this.context, {
      name: 'voxcarve.db', securityLevel: relationalStore.SecurityLevel.S2
    });
    if (store.version === 0) {
      await store.executeSql(CREATE_PROJECTS);
      store.version = 1;
    }
    if (store.version === 1) {
      await store.executeSql('CREATE TABLE IF NOT EXISTS edit_history (' +
        'project_id INTEGER PRIMARY KEY, snapshot TEXT NOT NULL)');
      store.version = 2;
    }
    if (store.version !== SCHEMA_VERSION) {
      throw new Error('PROJECT_SCHEMA_UNSUPPORTED');
    }
    return store;
  }

  async list(): Promise<MediaProject[]> {
    const store = await this.open();
    const rows = await store.querySql('SELECT id, name, created_at_ms, updated_at_ms FROM projects ' +
      'ORDER BY updated_at_ms DESC, id DESC');
    try {
      const result: MediaProject[] = [];
      while (rows.goToNextRow()) {
        result.push({
          id: rows.getLong(0), name: rows.getString(1), createdAtMs: rows.getLong(2), updatedAtMs: rows.getLong(3)
        });
      }
      return result;
    } finally {
      rows.close();
    }
  }

  async create(rawName: string): Promise<MediaProject> {
    const name = rawName.trim();
    if (!name || name.length > 60) {
      throw new Error('INVALID_PROJECT_NAME');
    }
    const now = Date.now();
    const store = await this.open();
    const id = await store.insert('projects', { name: name, created_at_ms: now, updated_at_ms: now });
    if (id <= 0) {
      throw new Error('PROJECT_CREATE_FAILED');
    }
    return { id: id, name: name, createdAtMs: now, updatedAtMs: now };
  }

  async loadEdits(projectId: number): Promise<EditGraph | undefined> {
    const store = await this.open();
    const rows = await store.querySql('SELECT snapshot FROM edit_history WHERE project_id = ?', [projectId]);
    try {
      if (!rows.goToNextRow()) {
        return undefined;
      }
      return EditGraph.restore(JSON.parse(rows.getString(0)) as EditHistorySnapshot);
    } finally {
      rows.close();
    }
  }

  async saveEdits(projectId: number, graph: EditGraph): Promise<void> {
    const store = await this.open();
    await store.executeSql('INSERT OR REPLACE INTO edit_history (project_id, snapshot) VALUES (?, ?)',
      [projectId, JSON.stringify(graph.snapshot())]);
  }
}
