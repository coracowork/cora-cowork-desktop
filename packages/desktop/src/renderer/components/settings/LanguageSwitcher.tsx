import CoraCoworkSelect from '@/renderer/components/base/CoraCoworkSelect';
import type { SelectHandle } from '@arco-design/web-react/es/Select/interface';
import React, { useCallback, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { changeLanguage } from '@/renderer/services/i18n';

const LanguageSwitcher: React.FC = () => {
  const { i18n } = useTranslation();
  const selectRef = useRef<SelectHandle>(null);

  const handleLanguageChange = useCallback((value: string) => {
    // 切换前先 blur 触发元素，避免弹层和语言切换竞争布局
    // Blur before switching to avoid dropdown and language change fighting for layout
    selectRef.current?.blur?.();

    const applyLanguage = () => {
      changeLanguage(value).catch((error: Error) => {
        console.error('Failed to change language:', error);
      });
    };

    if (typeof window !== 'undefined' && 'requestAnimationFrame' in window) {
      // 延迟到下一帧执行，确保 DOM 动画已完成 / defer to next frame so DOM animations finish
      window.requestAnimationFrame(() => window.requestAnimationFrame(applyLanguage));
    } else {
      setTimeout(applyLanguage, 0);
    }
  }, []);

  return (
    <div className='flex items-center gap-8px'>
      <CoraCoworkSelect ref={selectRef} className='w-160px' value={i18n.language} onChange={handleLanguageChange}>
        <CoraCoworkSelect.Option value='zh-CN'>简体中文</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='zh-TW'>繁體中文</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='ja-JP'>日本語</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='ko-KR'>한국어</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='tr-TR'>Türkçe</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='ru-RU'>Русский</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='uk-UA'>Українська</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='pt-BR'>Português (BR)</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='de-DE'>Deutsch</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='es-ES'>Español</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='fr-FR'>Français</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='fa-IR'>فارسی</CoraCoworkSelect.Option>
        <CoraCoworkSelect.Option value='en-US'>English</CoraCoworkSelect.Option>
      </CoraCoworkSelect>
    </div>
  );
};

export default LanguageSwitcher;