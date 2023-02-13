#!/usr/bin/env python3

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

INPUT_DIR = os.getenv('DATA_FOLDER')

class MyHttpRequestHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.path = INPUT_DIR + '/index.html'
        return SimpleHTTPRequestHandler.do_GET(self)

    def do_POST(self):
        if self.path == '/payment':

            content_length = int(self.headers['Content-Length'])
            post_data_bytes = self.rfile.read(content_length)

            post_data_str = post_data_bytes.decode("UTF-8")
            list_of_post_data = post_data_str.split('&')

            post_data_dict = {}
            for item in list_of_post_data:
                variable, value = item.split('=')
                post_data_dict[variable] = value
            # make payment

            self.path = INPUT_DIR + '/okay.html'

        return SimpleHTTPRequestHandler.do_GET(self)

def run():
    httpd = HTTPServer(('', 8000), MyHttpRequestHandler)
    httpd.serve_forever()


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        exit(0)
