import React, { FC, useState, useCallback } from 'react'
import axios from 'axios'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import Grid from '@mui/material/Grid'
import Container from '@mui/material/Container'
import Box from '@mui/material/Box'
import MenuItem from '@mui/material/MenuItem'
import Select from '@mui/material/Select'
import InputLabel from '@mui/material/InputLabel'
import FormControl from '@mui/material/FormControl'
import useFilestore from '../hooks/useFilestore'
import FileUpload from '../components/widgets/FileUpload'
import CloudUploadIcon from '@mui/icons-material/CloudUpload'
import useSnackbar from '../hooks/useSnackbar'
import useApi from '../hooks/useApi'
import useRouter from '../hooks/useRouter'
import useAccount from '../hooks/useAccount'

const Session: FC = () => {
  const filestore = useFilestore()
  const snackbar = useSnackbar()
  const api = useApi()
  const {navigate, params} = useRouter()
  const account = useAccount()

  const [loading, setLoading] = useState(false)
  const [inputValue, setInputValue] = useState('')
  const [chatHistory, setChatHistory] = useState<Array<{user: string, message: string}>>([])
  const [files, setFiles] = useState<File[]>([])

  const handleInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setInputValue(event.target.value)
  }
  const session = account.sessions?.find(session => session.id === params["session_id"])

  const onSend = async () => {
      // const statusResult = await axios.post('/api/v1/sessions', {
      //   files: files,
      // })
      /// XXXXXXXXXXXXXXXXX NOT CREATE NEW ONE, NEED TO UPDATE (or even better,
      /// POST to a new endpoint to add to the chat reliably)
      try {
        const formData = new FormData()
        files.forEach((file) => {
          formData.append("files", file)
        })

        formData.set('input', inputValue)

        await api.put('/api/v1/sessions', formData, {
          // params: {
          //   path,
          // },
          // onUploadProgress: (progressEvent) => {
          //   const percent = progressEvent.total && progressEvent.total > 0 ?
          //     Math.round((progressEvent.loaded * 100) / progressEvent.total) :
          //     0
          //   setUploadProgress({
          //     percent,
          //     totalBytes: progressEvent.total || 0,
          //     uploadedBytes: progressEvent.loaded || 0,
          //   })
          // }
        })
        // result = true
      } catch(e) {
        console.log(e)
      }
      // setUploadProgress(undefined)
      // return result

    // TODO: put this in state, when user clicks send, POST all three things
    // (files, text, type) to a new endpoint which accepts files

    // const result = await filestore.upload("lhwoo", files)
    // if(!result) return
    // await filestore.loadFiles(filestore.path)
    // snackbar.success('Files Uploaded')
  }

  const onUpload = useCallback(async (files: File[]) => {
    console.log(files)
    setFiles(files)
  }, [
    filestore.path,
  ])

  const handleKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === 'Enter' && (event.shiftKey || event.ctrlKey)) {
      onSend()
      event.preventDefault()
    }
  }

  return (
    <Container sx={{ mt: 4, mb: 4, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', overflowX: 'hidden' }}>
      <Grid container spacing={3} direction="row" justifyContent="flex-start">
        <Grid item xs={12} md={12}>
          <Typography sx={{fontSize: "small", color: "gray"}}>Session {session?.name} in which we {session?.mode.toLowerCase()} {session?.type.toLowerCase()} with {session?.model_name}...</Typography>
          <br />
          {session?.interactions.messages.map((chat: any, index: any) => (
            <Typography key={index}><strong>{chat.user}:</strong> {chat.message}</Typography>
          ))}
        </Grid>
      </Grid>
      <Grid container item xs={12} md={8} direction="row" justifyContent="space-between" alignItems="center" sx={{ mt: 'auto', position: 'absolute', bottom: '5em', maxWidth: '800px' }}>
        <Grid item xs={12} md={11}>
          {session?.mode === 'Finetune' && session?.type === 'Images' && (
            <FileUpload
              sx={{
                width: '100%',
                mt: 2,
              }}
              onUpload={ onUpload }
            >
              <Button
                sx={{
                  width: '100%',
                }}
                variant="contained"
                color="secondary"
                endIcon={<CloudUploadIcon />}
              >
                Upload Files
              </Button>
              <Box
                sx={{
                  border: '1px dashed #ccc',
                  p: 2,
                  display: 'flex',
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'center',
                  minHeight: '100px',
                  cursor: 'pointer',
                  mb: 2,
                }}
              >
                <Typography
                  sx={{
                    color: '#999'
                  }}
                  variant="caption"
                >
                  drop files here to upload them ...
                  {
                    files.length > 0 && files.map((file) => (
                      <Typography key={file.name}>
                        {file.name} ({file.size} bytes) - {file.type}
                      </Typography>
                    ))
                  }
                </Typography>
              </Box>
            </FileUpload> )}
        </Grid>
        <Grid item xs={12} md={11}>
            <TextField
              fullWidth
              label={(
                session?.mode === 'Create' && session?.type === 'Text' ? 'Chat with base Mistral-7B-Instruct model' : session?.mode === 'Create' && session?.type === 'Images' ? 'Describe an image to create it with a base SDXL model' : session?.mode === 'Finetune' && session?.type === 'Text' ? 'Enter question-answer pairs to fine tune a language model' : 'Upload images and label them to fine tune an image model'
                ) + " (shift+enter to send)"
              }
              value={inputValue}
              disabled={loading}
              onChange={handleInputChange}
              name="ai_submit"
              multiline={true}
              onKeyDown={handleKeyDown}
            />
          </Grid>
        <Grid item xs={12} md={1}>
          <Button
            variant='contained'
            disabled={loading}
            onClick={ onSend }
            sx={{ ml: 2 }}
          >
            Send
          </Button>
        </Grid>
      </Grid>
    </Container>
  )
}

export default Session