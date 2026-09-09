import os
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
        print("Error:", e)
    return env

def main():
    env = load_env()
    supabase_url = env.get('SUPABASE_URL')
    supabase_key = env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    url = f"{supabase_url}/rest/v1/profiles?select=id,full_name,whatsapp_number&limit=5"
    req = urllib.request.Request(url, headers={
        'apikey': supabase_key,
        'Authorization': f'Bearer {supabase_key}'
    })
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            print("Profiles:", json.dumps(data, indent=2))
    except Exception as e:
        print(f"Request failed: {e}")

    url_tx = f"{supabase_url}/rest/v1/transactions?select=payment_reference,status,payout_status,payout_reference,amount,commission_amount&order=created_at.desc&limit=5"
    req_tx = urllib.request.Request(url_tx, headers={
        'apikey': supabase_key,
        'Authorization': f'Bearer {supabase_key}'
    })
    try:
        with urllib.request.urlopen(req_tx, timeout=10) as response:
            data = json.loads(response.read().decode())
            print("Transactions:", json.dumps(data, indent=2))
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    main()
