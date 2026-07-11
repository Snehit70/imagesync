Morphing organic blob — ImageSync's hero motif for status/permission/success screens; always contains a white circle with a raspberry icon.

```jsx
<MorphingBlob size={180}>
  <div style={{ width: 72, height: 72, background: '#fff', borderRadius: '50%', display: 'grid', placeItems: 'center' }}>
    <span className="material-icons" style={{ color: 'var(--raspberry)', fontSize: 32 }}>link</span>
  </div>
</MorphingBlob>
```

Sizes in the app: 180 (home hero), 150 (onboarding steps), 120 petal (clipboard-empty), 104 (success orb inside RippleRings). `color="var(--petal)"` for soft states.
