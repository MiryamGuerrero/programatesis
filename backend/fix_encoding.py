import sys

def fix_encoding(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Common UTF-8 misinterpretations
    replacements = {
        'Ã©': 'é',
        'Ã­': 'í',
        'Ã³': 'ó',
        'Ã¡': 'á',
        'Ã±': 'ñ',
        'Ã': 'Í',
        'Ã“': 'Ó',
        'Ã': 'Ú',
        'Ãš': 'Ú',
        'Ã ': 'à',
        'Ã': 'Á',
        'Â¿': '¿',
        'Â¡': '¡',
        'â€¢': '•',
        'âœ…': '✅',
        'â‰¤': '≤',
        'â‰¥': '≥',
        'ðŸ“‹': '📋',
        'âš ï¸': '⚠️',
        'ðŸ”´': '🔴',
        'ðŸ“‹': '📋',
        'ðŸ“': '📏',
        'â„¹ï¸': 'ℹ️',
        'ðŸ”µ': '🔵',
        'ðŸŸ£': '🟣',
        'ðŸŸ¢': '🟢',
        'ðŸŸ ': '🟠',
        'âœ…': '✅',
        'ðŸ‘‰': '👉',
        'âœ…': '✅',
        'âœ…': '✅',
        'âœ…': '✅',
        'Ãº': 'ú',
        'Ãœ': 'Ü',
        'Ã¼': 'ü',
        'â€”': '—',
        'â€“': '–',
    }
    
    # Sort replacements by length of key descending to avoid partial matches
    for old, new in sorted(replacements.items(), key=lambda x: len(x[0]), reverse=True):
        content = content.replace(old, new)
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    fix_encoding(sys.argv[1])
