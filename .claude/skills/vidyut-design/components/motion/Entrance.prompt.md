Staggered entrance — wrap each top-level element of a screen with sequential indices; they rise 30px and fade in with the spring curve.

```jsx
<Entrance index={0}><StatusHero … /></Entrance>
<Entrance index={1}><NearbyRelaysCard … /></Entrance>
<Entrance index={2}><ManualPairingForm … /></Entrance>
```
