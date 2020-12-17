import os
from pathlib import Path

for path in Path('results').rglob('*'):
    size = os.path.getsize(path)
    if path.suffix != '' and size > 10 * 2**20:  # 10 MB
        with open(path, 'w') as f:
            f.write('')
