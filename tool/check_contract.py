"""Verify the pinned backend contract without network or optional dependencies."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
raw = (root / 'docs/api/mobile.openapi.yaml').read_bytes()
lock = json.loads((root / 'docs/api/contract-lock.json').read_text(encoding='utf-8-sig'))
spec = json.loads(raw)
assert hashlib.sha256(raw).hexdigest() == lock['sha256'], 'Contract pin changed; review and update provenance.'
assert spec['info']['version'] == lock['version'] == '2.0.0'
assert {'status', 'access_token', 'expires_at'} <= set(spec['components']['schemas']['TokenResponse']['required'])
for path, method in [('/auth/login', 'post'), ('/auth/two-factor', 'post'), ('/auth/email/verify', 'post'), ('/workspaces/{workspace}/hours', 'post'), ('/workspaces/{workspace}/hours/{entry}', 'patch')]:
    assert spec['paths'][path][method]['operationId']
assert 'version' in spec['components']['schemas']['HoursUpdate']['required']
assert spec['paths']['/auth/google/challenge']['post']['operationId']
assert 'challenge_id' in spec['components']['schemas']['GoogleSocialInput']['required']
print('Pinned mobile API 2.0.0 and client assumptions verified.')
