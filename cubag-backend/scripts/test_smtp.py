import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

def test_smtp():
    smtp_host = os.getenv('SMTP_HOST')
    smtp_port = int(os.getenv('SMTP_PORT', 587))
    smtp_user = os.getenv('SMTP_USER')
    smtp_pass = os.getenv('SMTP_PASS')
    
    print(f"Testing connection to {smtp_host}:{smtp_port} as {smtp_user}...")
    
    msg = MIMEMultipart()
    msg['From'] = smtp_user
    msg['To'] = '758wess@gmail.com'
    msg['Subject'] = 'SMTP Test from CUBAG Backend'
    body = "This is a test email to verify SMTP configuration."
    msg.attach(MIMEText(body, 'plain'))

    try:
        if smtp_port == 465:
            print("Using SMTP_SSL for port 465...")
            server = smtplib.SMTP_SSL(smtp_host, smtp_port)
        else:
            print("Using standard SMTP with STARTTLS...")
            server = smtplib.SMTP(smtp_host, smtp_port)
            server.starttls()
            
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)
        server.quit()
        print("SUCCESS: Email sent successfully! Check your inbox.")
    except Exception as e:
        print("ERROR: Failed to send email.")
        print(str(e))

if __name__ == "__main__":
    test_smtp()
