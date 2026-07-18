/**
 * @license
 * Copyright 2025 CoraCowork (coracowork.shop)
 * SPDX-License-Identifier: Apache-2.0
 */

import React from 'react';
import LocalAgents from '@/renderer/pages/settings/AgentSettings/LocalAgents';
import CoraCoworkScrollArea from '@/renderer/components/base/CoraCoworkScrollArea';
import { useSettingsViewMode } from '../settingsViewContext';

const AgentModalContent: React.FC = () => {
  const viewMode = useSettingsViewMode();
  const isPageMode = viewMode === 'page';

  return (
    <div className='flex flex-col h-full w-full'>
      <CoraCoworkScrollArea className='flex-1 min-h-0 pb-16px scrollbar-hide' disableOverflow={isPageMode}>
        <LocalAgents />
      </CoraCoworkScrollArea>
    </div>
  );
};

export default AgentModalContent;
