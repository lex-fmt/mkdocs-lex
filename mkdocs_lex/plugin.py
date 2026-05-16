import os
import subprocess
from mkdocs.plugins import BasePlugin
from mkdocs.structure.files import File

class LexPlugin(BasePlugin):
    def on_files(self, files, config):
        lex_files = []
        # Find all .lex files
        for root, _, filenames in os.walk(config['docs_dir']):
            for filename in filenames:
                if filename.endswith('.lex'):
                    filepath = os.path.join(root, filename)
                    relpath = os.path.relpath(filepath, config['docs_dir'])
                    
                    # Create a File pretending to be .md so MkDocs processes it as a Page
                    fake_md_path = relpath[:-4] + '.md'
                    f = File(
                        path=fake_md_path,
                        src_dir=config['docs_dir'],
                        dest_dir=config['site_dir'],
                        use_directory_urls=config.get('use_directory_urls', True)
                    )
                    # Point its physical absolute path back to the .lex file!
                    f.abs_src_path = filepath
                    lex_files.append(f)
                    
        # Remove any existing .lex files that MkDocs might have added as static resources
        files_to_keep = [f for f in files if not f.src_path.endswith('.lex')]
        files_to_keep.extend(lex_files)
        
        # We must return a Files object, not a list. We can construct one or modify the existing.
        # Actually MkDocs 1.x `files` is a Files collection, we can just clear and append.
        files._files = []
        for f in files_to_keep:
            files.append(f)
            
        return files

    def on_page_read_source(self, page, config):
        if page.file.abs_src_path.endswith('.lex'):
            print(f"Plugin converting to Markdown: {page.file.abs_src_path}")
            result = subprocess.run(
                ['lexd', 'convert', '--to', 'markdown', page.file.abs_src_path],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout
        return None
