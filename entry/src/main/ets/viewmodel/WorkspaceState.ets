import type { MediaProject } from '../domain/MediaModels';

export type ProjectListStatus = 'loading' | 'ready' | 'error';

export interface ProjectListState {
  readonly status: ProjectListStatus;
  readonly projects: MediaProject[];
}

export class VoxRoute {
  static readonly Projects = 'projects';
  static readonly Import = 'import';
  static readonly NewProject = 'new-project';
  static readonly Transcript = 'transcript';
  static readonly Timeline = 'timeline';
  static readonly Silence = 'silence';
  static readonly Captions = 'captions';
  static readonly Preview = 'preview';
  static readonly Export = 'export';
  static readonly History = 'history';
  static readonly Settings = 'settings';
  static readonly Probe = 'sdk26-probe';
}

export interface WorkspaceLink {
  readonly route: string;
  readonly label: string;
}

export const WORKSPACE_LINKS: WorkspaceLink[] = [
  { route: VoxRoute.Import, label: '音频导入' },
  { route: VoxRoute.Transcript, label: '文字稿' },
  { route: VoxRoute.Silence, label: '停顿复核' },
  { route: VoxRoute.Captions, label: '字幕' },
  { route: VoxRoute.Preview, label: '剪后试听' },
  { route: VoxRoute.Export, label: '导出' },
  { route: VoxRoute.History, label: '历史与版本' }
];

export function workspaceTitle(route: string): string {
  const link = WORKSPACE_LINKS.find((item: WorkspaceLink): boolean => item.route === route);
  return link?.label ?? '页面不可用';
}
