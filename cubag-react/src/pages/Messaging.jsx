import { useState, useEffect, useRef } from 'react'
import { useLocation } from 'react-router-dom'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Messaging() {
  const [activeChat, setActiveChat] = useState(null)
  const [conversations, setConversations] = useState([])
  const [messages, setMessages] = useState([])
  const [newMsg, setNewMsg] = useState('')
  const [loading, setLoading] = useState(true)
  const bottomRef = useRef(null)
  const location = useLocation()

  // Load conversations from backend
  const fetchConversations = async () => {
    try {
      const res = await fetch(`${API_URL}/messages/conversations`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) setConversations(await res.json())
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchConversations()
  }, [])

  // Handle incoming chat requests from Networking page
  useEffect(() => {
    if (location.state?.chatUser) {
      const u = location.state.chatUser;
      const initials = (u.name || 'U').split(' ').map(n => n[0]).join('').toUpperCase().slice(0,2)
      
      const chatTarget = {
        id: u.id,
        name: u.name,
        company: u.company || 'Member',
        initials: initials
      }
      
      openChat(chatTarget)
      // Clear the state so refreshing doesn't keep reopening the chat
      window.history.replaceState({}, '')
    }
  }, [location.state])

  const openChat = async (target) => {
    setActiveChat(target)
    setMessages([])
    try {
      const res = await fetch(`${API_URL}/messages/${target.id}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) setMessages(await res.json())
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const sendMessage = async () => {
    if (!newMsg.trim() || !activeChat) return
    const textToSend = newMsg
    setNewMsg('')

    try {
      const res = await fetch(`${API_URL}/messages/${activeChat.id}`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` 
        },
        body: JSON.stringify({ text: textToSend })
      })

      if (res.ok) {
        const savedMsg = await res.json()
        setMessages(prev => [...prev, savedMsg])
        fetchConversations() // refresh the list
      }
    } catch (e) {
      console.error('Failed to send message', e)
    }
  }

  return (
    <AppLayout title={activeChat ? 'Chat' : 'Messages'} hideSearch>
      <div style={{ height: 'calc(100vh - 140px)', display: 'flex', flexDirection: 'column' }}>

        {!activeChat ? (
          // Conversations List View
          <div className="feed-card" style={{ flex: 1, padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <div style={{ padding: '20px', borderBottom: '1px solid var(--border-subtle)' }}>
              <input
                type="text"
                placeholder="Search messages..."
                style={{ width: '100%', padding: '12px 16px', border: '1.5px solid var(--border-default)', borderRadius: 12, background: 'var(--bg-base)', color: 'var(--text-primary)', fontSize: '0.95rem' }}
              />
            </div>

            {conversations.length === 0 ? (
              // Empty state
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16, padding: '40px 24px', textAlign: 'center' }}>
                <div style={{ width: 72, height: 72, borderRadius: '50%', background: 'rgba(240,130,50,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '2.4rem', color: 'var(--brand-primary)' }}>chat_bubble</span>
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '1.1rem', color: 'var(--text-primary)', marginBottom: 8 }}>No messages yet</div>
                  <div style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.6, maxWidth: 280 }}>
                    Your conversations with CUBAG secretariat and other members will appear here.
                  </div>
                </div>
              </div>
            ) : (
              <div style={{ flex: 1, overflowY: 'auto' }}>
                {conversations.map(conv => (
                  <div
                    key={conv.id}
                    onClick={() => openChat(conv)}
                    style={{ display: 'flex', gap: 14, padding: '16px 20px', cursor: 'pointer', borderBottom: '1px solid var(--border-subtle)', transition: 'background 0.2s' }}
                  >
                    <div style={{ width: 48, height: 48, borderRadius: '50%', background: 'var(--brand-primary)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, flexShrink: 0 }}>
                      {conv.initials}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                        <span style={{ fontWeight: 700, fontSize: '0.95rem', color: 'var(--text-primary)' }}>{conv.name}</span>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{conv.time}</span>
                      </div>
                      <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{conv.lastMsg}</div>
                    </div>
                    {conv.unread > 0 && (
                      <div style={{ width: 22, height: 22, borderRadius: '50%', background: 'var(--brand-primary)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.7rem', fontWeight: 800, flexShrink: 0, marginTop: 4 }}>
                        {conv.unread}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          // Active Chat View
          <div className="feed-card" style={{ flex: 1, padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            {/* Chat Header */}
            <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', gap: 12 }}>
              <button onClick={() => setActiveChat(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', padding: 4 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.5rem' }}>arrow_back_ios_new</span>
              </button>
              <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'var(--brand-primary)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, flexShrink: 0 }}>
                {activeChat.initials}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 800, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{activeChat.name}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{activeChat.company}</div>
              </div>
            </div>

            {/* Messages */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: 12, background: 'var(--bg-base)' }}>
              {messages.length === 0 && (
                <div style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: 40 }}>
                  No messages yet. Say hello!
                </div>
              )}
              {messages.map(msg => (
                <div key={msg.id} style={{ display: 'flex', justifyContent: msg.from === 'me' ? 'flex-end' : 'flex-start' }}>
                  <div style={{
                    maxWidth: '80%', padding: '12px 16px',
                    borderRadius: msg.from === 'me' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                    background: msg.from === 'me' ? 'var(--brand-primary)' : '#fff',
                    color: msg.from === 'me' ? '#fff' : 'var(--text-primary)',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    fontSize: '0.9rem', lineHeight: 1.5
                  }}>
                    {msg.text}
                    <div style={{ fontSize: '0.65rem', opacity: 0.7, marginTop: 4, textAlign: 'right' }}>{msg.time}</div>
                  </div>
                </div>
              ))}
              <div ref={bottomRef} />
            </div>

            {/* Input */}
            <div style={{ padding: '12px 16px', borderTop: '1px solid var(--border-subtle)', display: 'flex', gap: 12, background: '#fff' }}>
              <input
                type="text"
                value={newMsg}
                onChange={e => setNewMsg(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && sendMessage()}
                placeholder="Type a message..."
                style={{ flex: 1, padding: '12px 16px', border: '1.5px solid var(--border-default)', borderRadius: 24, background: 'var(--bg-base)', color: 'var(--text-primary)', fontSize: '0.95rem', outline: 'none' }}
              />
              <button onClick={sendMessage} className="btn btn-primary" style={{ width: 46, height: 46, borderRadius: '50%', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ marginLeft: 4 }}>send</span>
              </button>
            </div>
          </div>
        )}

      </div>
    </AppLayout>
  )
}
