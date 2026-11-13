import { AudioWorkspace } from '../components/AudioWorkspace';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import type { MediaProject } from '../domain/MediaModels';
import { LocalProjectRepository, ProjectRepository } from '../repository/ProjectRepository';
import { AppAccent, XuzuoTheme } from '../components/XuzuoTheme';
import {
  ActionButton, DataRow, EmptyPanel, ErrorPanel, SegmentedControl, StatusChip, TaskProgress, TextFieldRow,
  XuzuoChoice, showConfirmDialog
} from '../components/XuzuoControls';
import { NavigationShell, XuzuoAppBar } from '../components/NavigationShell';
import { TranscriptPane } from '../components/AudioEditorPanes';
import { ProjectListState, VoxRoute, WORKSPACE_LINKS, WorkspaceLink, workspaceTitle } from '../viewmodel/WorkspaceState';
import { SdkProbePanel } from './SdkProbePanel';

const PRIMARY_LINKS: XuzuoChoice[] = [
  { id: VoxRoute.Projects, label: '项目' },
  { id: VoxRoute.Timeline, label: '剪辑台' },
  { id: VoxRoute.Settings, label: '设置' }
];

const THEME_CHOICES: XuzuoChoice[] = [
  { id: 'system', label: '跟随系统' },
  { id: 'light', label: '浅色' },
  { id: 'dark', label: '深色' }
];

@Entry
@Component
struct Index {
  @State private activeTab: string = VoxRoute.Projects;
  @State private activeProject?: MediaProject = undefined;
  @State private listState: ProjectListState = { status: 'loading', projects: [] };
  @State private projectName: string = '';
  @State private createError: string = '';
  @State private savingProject: boolean = false;
  @State private wide: boolean = false;
  @State private themeChoice: string = 'system';
  @State private themeError: boolean = false;
  private paths: NavPathStack = new NavPathStack();
  private repository?: ProjectRepository;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.repository = new LocalProjectRepository(context);
    this.loadProjects();
  }

  private async loadProjects(): Promise<void> {
    const repository = this.repository;
    if (!repository || this.savingProject) {
      return;
    }
    this.listState = { status: 'loading', projects: this.listState.projects };
    try {
      this.listState = { status: 'ready', projects: await repository.list() };
    } catch (error) {
      this.listState = { status: 'error', projects: this.listState.projects };
    }
  }

  private openImport(): void {
    this.projectName = '';
    this.createError = '';
    this.paths.pushPath({ name: VoxRoute.Import }, false);
  }

  private async createProject(): Promise<void> {
    const repository = this.repository;
    if (!repository || this.savingProject || !this.projectName.trim()) {
      return;
    }
    this.savingProject = true;
    this.createError = '';
    try {
      const project = await repository.create(this.projectName);
      this.listState = { status: 'ready', projects: [project].concat(this.listState.projects) };
      this.activeProject = project;
      this.projectName = '';
      this.activeTab = VoxRoute.Projects;
      this.paths.pop(false);
    } catch (error) {
      this.createError = '项目未保存，请重试。';
    } finally {
      this.savingProject = false;
    }
  }

  private leaveImport(): void {
    if (this.savingProject) {
      return;
    }
    if (this.projectName.trim()) {
      showConfirmDialog(this.getUIContext(), '放弃新建项目？', '已输入的项目名称会被清除。', '放弃', () => {
        this.projectName = '';
        this.paths.pop(false);
      });
    } else {
      this.paths.pop(false);
    }
  }

  private selectTheme(id: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (id === 'light') {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (id === 'dark') {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      context.getApplicationContext().setColorMode(mode);
      this.themeChoice = id;
      this.themeError = false;
    } catch (error) {
      this.themeError = true;
    }
  }

  @Builder
  sectionTitle(title: string) {
    Text(title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(XuzuoTheme.textPrimary)
  }

  @Builder
  projects() {
    Column({ space: 16 }) {
      this.sectionTitle('本地项目')
      if (this.listState.status === 'loading') {
        TaskProgress({ label: '正在读取项目' })
      } else if (this.listState.status === 'error') {
        ErrorPanel({ message: '无法读取本地项目。请重试。', action: () => { this.loadProjects() } })
      } else if (this.listState.projects.length === 0) {
        EmptyPanel({
          title: '还没有项目',
          detail: '项目保存在这台设备上。',
          actionLabel: '新建项目',
          action: () => this.openImport()
        })
      } else {
        ActionButton({ label: '新建项目', variant: 'primary', action: () => this.openImport() })
        ForEach(this.listState.projects, (project: MediaProject) => {
          DataRow({
            title: project.name,
            action: () => {
              this.activeProject = project;
              this.activeTab = VoxRoute.Timeline;
            }
          })
        }, (project: MediaProject): string => project.id.toString())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  timeline() {
    Column({ space: 12 }) {
      this.sectionTitle(this.activeProject?.name ?? '音频剪辑台')
      AudioWorkspace({ project: this.activeProject, repository: this.repository })
      if (!this.activeProject) {
        ActionButton({ label: '查看本地项目', action: () => { this.activeTab = VoxRoute.Projects } })
      }
      ForEach(WORKSPACE_LINKS, (link: WorkspaceLink) => {
        DataRow({ title: link.label, action: () => this.paths.pushPath({ name: link.route }, false) })
      }, (link: WorkspaceLink): string => link.route)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  settings() {
    Column({ space: 16 }) {
      this.sectionTitle('设置')
      Text('外观').fontSize(17).fontWeight(FontWeight.Medium).fontColor(XuzuoTheme.textPrimary)
      SegmentedControl({
        options: THEME_CHOICES, selectedId: this.themeChoice, select: (id: string) => this.selectTheme(id)
      })
      if (this.themeError) {
        ErrorPanel({ message: '外观切换失败。', actionLabel: '' })
      }
      Divider().color(XuzuoTheme.outline)
      Text('媒体与语音').fontSize(17).fontWeight(FontWeight.Medium).fontColor(XuzuoTheme.textPrimary)
      Text('项目保存在设备上。当前版本仅提供离线语音能力探测。')
        .fontSize(15).fontColor(XuzuoTheme.textSecondary)
      DataRow({ title: 'SDK 26 探测', detail: '文件权限、音频与离线语种',
        action: () => this.paths.pushPath({ name: VoxRoute.Probe }, false) })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  homeContent() {
    Scroll() {
      Column() {
        if (this.activeTab === VoxRoute.Projects) {
          this.projects()
        } else if (this.activeTab === VoxRoute.Timeline) {
          this.timeline()
        } else {
          this.settings()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: XuzuoTheme.contentWidth })
      .padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  @Builder
  importContent() {
    Column({ space: 16 }) {
      TextFieldRow({
        label: '项目名称',
        fieldValue: this.projectName,
        update: (text: string) => {
          this.projectName = text;
          this.createError = '';
        }
      })
      Text('项目将保存在本机。创建后可在剪辑台导入 WAV。')
        .fontSize(15).fontColor(XuzuoTheme.textSecondary)
      if (this.createError) {
        ErrorPanel({ message: this.createError, actionLabel: '' })
      }
      ActionButton({
        label: '创建项目',
        variant: 'primary',
        available: this.projectName.trim().length > 0,
        pending: this.savingProject,
        action: () => { this.createProject() }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  destination(route: string) {
    NavDestination() {
      Column() {
        XuzuoAppBar({
          title: route === VoxRoute.Import ? '新建与导入' :
            route === VoxRoute.Probe ? 'SDK 26 探测' : workspaceTitle(route),
          backAvailable: true,
          back: () => {
            if (route === VoxRoute.Import) {
              this.leaveImport();
            } else {
              this.paths.pop(false);
            }
          }
        })
        Scroll() {
          Column({ space: 12 }) {
            if (route === VoxRoute.Import) {
              this.importContent()
            } else if (route === VoxRoute.Transcript) {
              TranscriptPane()
            } else if (route === VoxRoute.Probe) {
              SdkProbePanel()
            } else {
              EmptyPanel({ title: '当前没有可处理的音轨',
                detail: '这里会随项目音频处理结果更新。' })
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: XuzuoTheme.contentWidth })
          .padding(20)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(XuzuoTheme.background)
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      if (route === VoxRoute.Import) {
        this.leaveImport();
        return true;
      }
      return false;
    })
  }

  build() {
    Column() {
      Navigation(this.paths) {
        Column() {
          XuzuoAppBar({ title: '声剪' })
          Divider().color(XuzuoTheme.outline)
          if (this.wide) {
            Row() {
              NavigationShell({
                options: PRIMARY_LINKS, selectedId: this.activeTab, wide: true,
                select: (id: string) => { this.activeTab = id }
              })
              this.homeContent()
            }
            .width('100%')
            .layoutWeight(1)
            .alignItems(VerticalAlign.Top)
          } else {
            this.homeContent()
            Divider().color(XuzuoTheme.outline)
            NavigationShell({
              options: PRIMARY_LINKS, selectedId: this.activeTab,
              select: (id: string) => { this.activeTab = id }
            })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(XuzuoTheme.background)
      }
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .navDestination(this.destination)
      .width('100%')
      .height('100%')
      .onAreaChange((_oldArea: Area, next: Area) => {
        this.wide = Number(next.width) >= XuzuoTheme.sidebarBreakpoint;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(XuzuoTheme.background)
  }
}
