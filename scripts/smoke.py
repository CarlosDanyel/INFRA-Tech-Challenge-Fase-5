import concurrent.futures
import io
import json
import os
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import zipfile
from pathlib import Path

base_url = os.environ.get('FIAPX_URL', 'http://localhost:18080')
mailpit_url = os.environ.get('FIAPX_MAILPIT_URL')
email = f'smoke-{uuid.uuid4()}@example.com'


def request(path, method='GET', body=None, token=None, content_type=None):
    headers = {}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    if content_type:
        headers['Content-Type'] = content_type
    call = urllib.request.Request(base_url + path, data=body, headers=headers, method=method)
    with urllib.request.urlopen(call, timeout=30) as response:
        return response.read()


def upload(content, name, token):
    boundary = uuid.uuid4().hex
    body = (
        f'--{boundary}\r\n'
        f'Content-Disposition: form-data; name="video"; filename="{name}"\r\n'
        'Content-Type: video/mp4\r\n\r\n'
    ).encode() + content + f'\r\n--{boundary}--\r\n'.encode()
    response = request('/api/videos', 'POST', body, token, f'multipart/form-data; boundary={boundary}')
    return json.loads(response)['id']


def wait_for(video_id, token, target):
    for _ in range(90):
        video = json.loads(request(f'/api/videos/{video_id}', token=token))
        if video['status'] == target:
            return video
        if video['status'] in ('COMPLETED', 'FAILED'):
            raise AssertionError(f'Video {video_id} ended as {video["status"]}')
        time.sleep(1)
    raise TimeoutError(f'Video {video_id} did not reach {target}')


def verify_mail():
    if not mailpit_url:
        return
    for _ in range(30):
        with urllib.request.urlopen(mailpit_url + '/api/v1/messages', timeout=5) as response:
            messages = json.load(response)['messages']
        if any(message['Subject'] == 'FIAP X: video processing failed'
               and any(recipient['Address'] == email for recipient in message['To'])
               for message in messages):
            return
        time.sleep(1)
    raise AssertionError('Mailpit did not receive the failure email')


token = json.loads(request('/api/auth/register', 'POST', json.dumps({
    'email': email, 'password': 'smoke-password-123'
}).encode(), content_type='application/json'))['token']

with tempfile.TemporaryDirectory() as directory:
    video_path = Path(directory) / 'sample.mp4'
    subprocess.run([
        'ffmpeg', '-loglevel', 'error', '-f', 'lavfi', '-i',
        'color=c=blue:s=16x16:d=2', '-y', str(video_path)
    ], check=True)
    content = video_path.read_bytes()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        ids = list(pool.map(lambda _: upload(content, 'sample.mp4', token), range(2)))
    assert len(set(ids)) == 2
    for video_id in ids:
        result = wait_for(video_id, token, 'COMPLETED')
        assert result['frameCount'] == 2
        archive = request(f'/api/videos/{video_id}/download', token=token)
        with zipfile.ZipFile(io.BytesIO(archive)) as frames:
            assert len(frames.namelist()) == 2
            assert all(name.endswith('.png') for name in frames.namelist())

    invalid_id = upload(b'not a video', 'invalid.mp4', token)
    wait_for(invalid_id, token, 'FAILED')
    verify_mail()
    retry = json.loads(request(f'/api/videos/{invalid_id}/retry', 'POST', b'', token))
    assert retry['status'] == 'QUEUED'
    wait_for(invalid_id, token, 'FAILED')

print('Two concurrent videos, ZIPs, failure email and retry passed')
