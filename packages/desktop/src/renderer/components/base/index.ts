/**
 * @license
 * Copyright 2025 CoraCowork (coracowork.com)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * CoraCowork 基础组件库统一导出 / CoraCowork base components unified exports
 *
 * 提供所有基础组件和类型的统一导出入口
 * Provides unified export entry for all base components and types
 */

// ==================== 组件导出 / Component Exports ====================

export { default as CoraCoworkModal } from './CoraCoworkModal';
export { default as CoraCoworkCollapse } from './CoraCoworkCollapse';
export { default as CoraCoworkSelect } from './CoraCoworkSelect';
export { default as CoraCoworkScrollArea } from './CoraCoworkScrollArea';
export { default as CoraCoworkSteps } from './CoraCoworkSteps';
export { default as CoraSearchInput } from './CoraSearchInput';
export { default as CoraInlineSearchInput } from './CoraInlineSearchInput';

// ==================== 类型导出 / Type Exports ====================

// CoraModal 类型 / CoraModal types
export type {
  ModalSize,
  ModalHeaderConfig,
  ModalFooterConfig,
  ModalContentStyleConfig,
  CoraCoworkModalProps,
} from './CoraCoworkModal';
export { MODAL_SIZES } from './CoraCoworkModal';

// CoraCollapse 类型 / CoraCollapse types
export type { CoraCoworkCollapseProps, CoraCoworkCollapseItemProps } from './CoraCoworkCollapse';

// CoraSelect 类型 / CoraSelect types
export type { CoraCoworkSelectProps } from './CoraCoworkSelect';

// CoraSteps 类型 / CoraSteps types
export type { CoraCoworkStepsProps } from './CoraCoworkSteps';

// CoraSearchInput 类型 / CoraSearchInput types
export type { CoraSearchInputProps } from './CoraSearchInput';

// CoraInlineSearchInput 类型 / CoraInlineSearchInput types
export type { CoraInlineSearchInputProps } from './CoraInlineSearchInput';
