import { useState } from 'react';

/**
 * Inline ⓘ icon that shows a popover on hover.
 *
 * Props:
 *   content  – JSX or string rendered inside the popover
 *   width    – popover width in px (default 300)
 *   position – 'below' | 'above' (default 'below')
 */
export default function InfoTip({ content, width = 300, position = 'below' }) {
  const [visible, setVisible] = useState(false);

  return (
    <span
      style={{ position: 'relative', display: 'inline-block', marginLeft: 5, verticalAlign: 'middle' }}
      onMouseEnter={() => setVisible(true)}
      onMouseLeave={() => setVisible(false)}
    >
      <span style={{
        display:        'inline-flex',
        alignItems:     'center',
        justifyContent: 'center',
        width:          15,
        height:         15,
        borderRadius:   '50%',
        border:         '1.5px solid var(--neutral-500)',
        color:          'var(--neutral-500)',
        fontSize:       10,
        fontWeight:     700,
        cursor:         'help',
        lineHeight:     1,
        userSelect:     'none',
      }}>
        i
      </span>
      {visible && (
        <div style={{
          position:     'absolute',
          top:          position === 'above' ? 'auto' : 'calc(100% + 6px)',
          bottom:       position === 'above' ? 'calc(100% + 6px)' : 'auto',
          left:         '50%',
          transform:    'translateX(-50%)',
          zIndex:       200,
          width,
          background:   'white',
          border:       '1px solid var(--neutral-200)',
          borderRadius: 8,
          padding:      '12px 14px',
          boxShadow:    '0 4px 16px rgba(0,0,0,0.12)',
          fontSize:     12,
          lineHeight:   1.6,
          color:        'var(--neutral-700)',
          textAlign:    'left',
          fontWeight:   'normal',
          whiteSpace:   'normal',
        }}>
          {content}
        </div>
      )}
    </span>
  );
}
