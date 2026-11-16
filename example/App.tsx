import React, { useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  Alert,
  I18nManager,
  ScrollView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import { startChat } from 'react-native-revechat';

const ORANGE = '#EF6C00';
const STORAGE_KEY = 'revechat_example_form';

// The host app stays left-to-right; this only chooses the language of the chat screens.
I18nManager.allowRTL(false);
I18nManager.forceRTL(false);

type BackgroundChoice = 'light' | 'dark' | 'system';
const BACKGROUNDS: { value: BackgroundChoice; label: string }[] = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
];

type LanguageChoice = 'system' | 'en' | 'ar';
const LANGUAGES: { value: LanguageChoice; label: string }[] = [
  { value: 'system', label: 'System' },
  { value: 'en', label: 'English' },
  { value: 'ar', label: 'Arabic' },
];

export default function App() {
  return (
    <SafeAreaProvider>
      <Home />
    </SafeAreaProvider>
  );
}

function Home() {
  const insets = useSafeAreaInsets();
  const [accountId, setAccountId] = useState('');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [busy, setBusy] = useState(false);
  const [customFont, setCustomFont] = useState(false);
  const [language, setLanguage] = useState<LanguageChoice>('system');
  const [languageOpen, setLanguageOpen] = useState(false);
  const [background, setBackground] = useState<BackgroundChoice>('light');
  const [backgroundOpen, setBackgroundOpen] = useState(false);
  const [backgroundColor, setBackgroundColor] = useState('');
  const [restored, setRestored] = useState(false);

  // Remember the form between launches.
  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY)
      .then(raw => {
        if (raw) {
          const saved = JSON.parse(raw);
          setAccountId(saved.accountId ?? '');
          setName(saved.name ?? '');
          setEmail(saved.email ?? '');
          setPhone(saved.phone ?? '');
          setCustomFont(!!saved.customFont);
          if (BACKGROUNDS.some(b => b.value === saved.background)) {
            setBackground(saved.background);
          }
          setBackgroundColor(saved.backgroundColor ?? '');
          if (LANGUAGES.some(l => l.value === saved.language)) {
            setLanguage(saved.language);
          }
        }
      })
      .catch(() => {})
      .finally(() => setRestored(true));
  }, []);

  useEffect(() => {
    if (restored) {
      AsyncStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ accountId, name, email, phone, customFont, language, background, backgroundColor }),
      ).catch(() => {});
    }
  }, [restored, accountId, name, email, phone, customFont, language, background, backgroundColor]);

  const onStartChat = async () => {
    if (!accountId.trim()) {
      Alert.alert('ReveChat', 'Please enter the account ID.');
      return;
    }
    if (email.trim() && !/^\S+@\S+\.\S+$/.test(email.trim())) {
      Alert.alert('ReveChat', 'Please enter a valid email address.');
      return;
    }
    setBusy(true);
    try {
      // The four values are passed straight to the native Android / iOS SDK.
      await startChat({
        accountId: accountId.trim(),
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        // The language of the chat screens only; the host app itself is not changed. System follows the phone.
        language: language === 'system' ? undefined : language,
        // Background of the chat screens chosen by this host app; the exact colour wins over the theme.
        backgroundTheme: background,
        backgroundColor: backgroundColor.trim() || undefined,
        font: customFont
          ? {
              regular: 'fonts/Xarrovv.otf',
            }
          : undefined,
      });
    } catch (e) {
      Alert.alert('ReveChat', e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={[styles.safe, { paddingBottom: insets.bottom }]}>
      <StatusBar barStyle="light-content" />
      <Text style={[styles.toolbar, { paddingTop: 16 + insets.top }]}>
        ReveChat Example
      </Text>
      <ScrollView
        contentContainerStyle={styles.body}
        keyboardShouldPersistTaps="handled">
        <Text style={styles.welcome}>
          Fill in the details to start a chat.
        </Text>
        <TextInput
          style={styles.input}
          placeholderTextColor="#999"
          placeholder="Account ID"
          keyboardType="number-pad"
          value={accountId}
          onChangeText={setAccountId}
        />
        <TextInput
          style={styles.input}
          placeholderTextColor="#999"
          placeholder="Name"
          value={name}
          onChangeText={setName}
        />
        <TextInput
          style={styles.input}
          placeholderTextColor="#999"
          placeholder="Email"
          keyboardType="email-address"
          autoCapitalize="none"
          value={email}
          onChangeText={setEmail}
        />
        <TextInput
          style={styles.input}
          placeholderTextColor="#999"
          placeholder="Phone"
          keyboardType="phone-pad"
          value={phone}
          onChangeText={setPhone}
        />
        <TouchableOpacity
          style={[styles.button, busy && styles.buttonDisabled]}
          disabled={busy}
          onPress={onStartChat}>
          <Text style={styles.buttonText}>CHAT WITH US</Text>
        </TouchableOpacity>
        <View style={styles.row}>
          <Text style={styles.rowLabel}>Chat language</Text>
          <TouchableOpacity
            style={styles.dropdown}
            onPress={() => setLanguageOpen(open => !open)}>
            <Text style={styles.dropdownText}>
              {LANGUAGES.find(l => l.value === language)?.label} {languageOpen ? '\u25B4' : '\u25BE'}
            </Text>
          </TouchableOpacity>
        </View>
        {languageOpen && (
          <View style={styles.dropdownList}>
            {LANGUAGES.map(l => (
              <TouchableOpacity
                key={l.value}
                style={styles.dropdownItem}
                onPress={() => {
                  setLanguage(l.value);
                  setLanguageOpen(false);
                }}>
                <Text
                  style={[
                    styles.dropdownText,
                    l.value === language && styles.dropdownSelected,
                  ]}>
                  {l.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}
        <View style={styles.row}>
          <Text style={styles.rowLabel}>Chat background</Text>
          <TouchableOpacity
            style={styles.dropdown}
            onPress={() => setBackgroundOpen(open => !open)}>
            <Text style={styles.dropdownText}>
              {BACKGROUNDS.find(b => b.value === background)?.label} {backgroundOpen ? '\u25B4' : '\u25BE'}
            </Text>
          </TouchableOpacity>
        </View>
        {backgroundOpen && (
          <View style={styles.dropdownList}>
            {BACKGROUNDS.map(b => (
              <TouchableOpacity
                key={b.value}
                style={styles.dropdownItem}
                onPress={() => {
                  setBackground(b.value);
                  setBackgroundOpen(false);
                }}>
                <Text
                  style={[
                    styles.dropdownText,
                    b.value === background && styles.dropdownSelected,
                  ]}>
                  {b.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}
        <TextInput
          style={[styles.input, { marginTop: 12 }]}
          placeholder="Exact colour, e.g. #101820 (optional)"
          placeholderTextColor="#888"
          autoCapitalize="none"
          value={backgroundColor}
          onChangeText={setBackgroundColor}
        />
        <View style={styles.row}>
          <Text style={styles.rowLabel}>Custom font (Xarrovv)</Text>
          <Switch value={customFont} onValueChange={setCustomFont} />
        </View>
      </ScrollView>
    </View>
  );
}

// No left/right anywhere: text uses the default start alignment, spacing uses start/end,
// so the screen mirrors correctly when RTL is on.
const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#fff' },
  toolbar: {
    backgroundColor: ORANGE,
    color: '#fff',
    fontSize: 20,
    fontWeight: '600',
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  body: { padding: 16 },
  welcome: { fontSize: 18, color: '#000', marginVertical: 16 },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 4,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    marginBottom: 12,
    color: '#000',
  },
  button: {
    backgroundColor: ORANGE,
    borderRadius: 4,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 16,
    elevation: 3,
  },
  buttonDisabled: { opacity: 0.6 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 24,
  },
  rowLabel: { fontSize: 16, color: '#000' },
  dropdown: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 8,
    minWidth: 130,
  },
  dropdownList: {
    alignSelf: 'flex-end',
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 6,
    minWidth: 130,
    marginBottom: 8,
  },
  dropdownItem: { paddingHorizontal: 12, paddingVertical: 10 },
  dropdownText: { fontSize: 16, color: '#000' },
  dropdownSelected: { fontWeight: '700', color: ORANGE },
});
