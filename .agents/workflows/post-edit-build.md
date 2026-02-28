---
description: Post-Edit Build and Cleanup Workflow
---
// turbo-all
1. Kill any existing instances of the app
```bash
killall VoiceOverlay || true
```

2. Clean and build the new application
```bash
make clean && make build
```

3. Run the new application
```bash
make run
```
