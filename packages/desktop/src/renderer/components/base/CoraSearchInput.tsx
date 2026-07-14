import { CloseSmall, Search } from '@icon-park/react';
import classNames from 'classnames';
import type { CSSProperties, InputHTMLAttributes, Ref } from 'react';
import React, { forwardRef } from 'react';
import { useTranslation } from 'react-i18next';
import styles from './CoraSearchInput.module.css';

export type CoraSearchInputProps = {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  allowClear?: boolean;
  onClear?: () => void;
  className?: string;
  style?: CSSProperties;
  autoFocus?: boolean;
  disabled?: boolean;
  'data-testid'?: string;
  wrapTestId?: string;
  inputProps?: Omit<
    InputHTMLAttributes<HTMLInputElement>,
    'value' | 'onChange' | 'placeholder' | 'disabled' | 'autoFocus' | 'className'
  >;
};

const CoraSearchInput = forwardRef<HTMLInputElement, CoraSearchInputProps>((props, ref) => {
  const {
    value,
    onChange,
    placeholder,
    allowClear = true,
    onClear,
    className,
    style,
    autoFocus,
    disabled,
    wrapTestId,
    inputProps,
  } = props;
  const { t } = useTranslation();

  const handleClear = () => {
    if (onClear) {
      onClear();
    } else {
      onChange('');
    }
  };

  return (
    <div className={classNames(styles.searchbar, className)} style={style} data-testid={wrapTestId}>
      <Search theme='outline' size='14' className={styles.icon} fill='currentColor' />
      <input
        {...inputProps}
        ref={ref as Ref<HTMLInputElement>}
        className={styles.input}
        value={value}
        placeholder={placeholder}
        disabled={disabled}
        autoFocus={autoFocus}
        data-testid={props['data-testid']}
        onChange={(event) => onChange(event.target.value)}
      />
      {allowClear && value ? (
        <button
          type='button'
          className={styles.clearBtn}
          onClick={handleClear}
          aria-label={t('common.clear', { defaultValue: 'Clear' })}
          tabIndex={-1}
        >
          <CloseSmall theme='outline' size='14' fill='currentColor' />
        </button>
      ) : null}
    </div>
  );
});

CoraSearchInput.displayName = 'CoraSearchInput';

export default CoraSearchInput;
