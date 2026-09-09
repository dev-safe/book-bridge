import os
import sys
import json
import urllib.request
import urllib.error

def load_env():
    env = {}
    env_path = os.path.join(os.path.dirname(__file__), '../.env')
    try:
        with open(env_path, 'r') as f:
            for line in f:
                if '=' in line:
                    key, val = line.strip().split('=', 1)
                    env[key.strip()] = val.strip()
    except Exception as e:
        print(f"Error loading .env: {e}")
    return env

def main():
    env = load_env()
    supabase_url = env.get('SUPABASE_URL')
    supabase_key = env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if not supabase_url or not supabase_key:
        print("Missing credentials in .env")
        sys.exit(1)
        
    url = f"{supabase_url}/rest/v1/transactions?select=*&order=created_at.desc&limit=5"
    req = urllib.request.Request(url, headers={
        'apikey': supabase_key,
        'Authorization': f'Bearer {supabase_key}'
    })
    
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            print(json.dumps(data, indent=2))
    except urllib.error.URLError as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    main()
