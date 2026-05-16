import os
import subprocess
import shutil
import pytest

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), 'fixtures')
SIMPLE_SITE_DIR = os.path.join(FIXTURES_DIR, 'simple_site')

def test_mkdocs_lex_integration():
    """
    Test that MkDocs successfully builds a site from Lex files.
    """
    # 1. Clean up any previous builds
    site_dir = os.path.join(SIMPLE_SITE_DIR, 'site')
    if os.path.exists(site_dir):
        shutil.rmtree(site_dir)
        
    # 2. Run MkDocs build
    # We use subprocess to simulate a real user build
    result = subprocess.run(
        ['mkdocs', 'build'],
        cwd=SIMPLE_SITE_DIR,
        capture_output=True,
        text=True
    )
    
    # 3. Assert build succeeded
    print("STDOUT:", result.stdout)
    print("STDERR:", result.stderr)
    assert result.returncode == 0, "MkDocs build failed!"
    
    # 4. Assert output HTML exists
    index_html_path = os.path.join(site_dir, 'index.html')
    assert os.path.exists(index_html_path), "index.html was not generated!"
    
    # 5. Assert the HTML contains expected content generated from the Lex file
    with open(index_html_path, 'r', encoding='utf-8') as f:
        html_content = f.read()
        
        # Check for the main title
        assert 'Hello Lex Integration' in html_content, "Lex title was not converted"
        
        # Check for the list items
        assert 'A test item' in html_content, "Lex lists were not converted"
        
        # Check for code blocks
        assert 'def hello():' in html_content, "Lex code block content was lost"
