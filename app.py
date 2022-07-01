
import subprocess
from flask import Flask, request, render_template

app = Flask(__name__)
app.config['TEMPLATES_AUTO_RELOAD'] = True

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/parser", methods=["POST"])
def parser():
    text = request.get_data()
    result = subprocess.run(['perl', 'parser.pl'], input=text, capture_output=True)
    return result.stdout.decode('utf-8')